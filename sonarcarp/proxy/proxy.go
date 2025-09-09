package proxy

import (
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/vulcand/oxy/v2/forward"
	"golang.org/x/time/rate"
)

var (
	mu      sync.RWMutex
	clients = make(map[string]*rate.Limiter)
)

type sonarAdminGroupMapping struct {
	cesAdminGroup   string
	sonarAdminGroup string
}

type authorizationHeaders struct {
	Principal string
	Role      string
	Mail      string
	Name      string
}

type proxyHandler struct {
	targetURL             *url.URL
	forwarder             http.Handler
	casClient             *cas.Client
	headers               authorizationHeaders
	logoutPath            string
	logoutRedirectionPath string
	casAuthenticated      func(r *http.Request) bool
	adminGroupMapping     sonarAdminGroupMapping
}

func createProxyHandler(headers authorizationHeaders, casClient *cas.Client, cfg config.Configuration) (http.Handler, error) {
	log.Debugf("creating proxy middleware")

	targetURL, err := url.Parse(cfg.ServiceUrl)
	if err != nil {
		return proxyHandler{}, fmt.Errorf("could not parse target url '%s': %w", cfg.ServiceUrl, err)
	}

	fwd := forward.New(true)

	pHandler := proxyHandler{
		targetURL:             targetURL,
		forwarder:             fwd,
		casAuthenticated:      cas.IsAuthenticated,
		headers:               headers,
		casClient:             casClient,
		logoutPath:            cfg.LogoutPath,
		logoutRedirectionPath: cfg.LogoutRedirectPath,
		adminGroupMapping:     sonarAdminGroupMapping{cesAdminGroup: cfg.CesAdminGroup, sonarAdminGroup: cfg.SonarAdminGroup},
	}

	casHandlingProxy := casClient.CreateHandler(pHandler)

	return casHandlingProxy, nil
}

func (p proxyHandler) isFrontChannelLogoutRequest(r *http.Request) bool {
	// Clicking on logout performs a browser side redirect from the actual logout path back to index => Backend cannot catch the first request
	// So in that case we use the referrer to check if a request is a logout request.
	return strings.HasSuffix(r.Referer(), p.logoutPath) && r.URL.Path == p.logoutRedirectionPath
}

func IsBrowserRequest(req *http.Request) bool {
	lowerUserAgent := strings.ToLower(req.Header.Get("User-Agent"))
	return strings.Contains(lowerUserAgent, "mozilla") || strings.Contains(lowerUserAgent, "opera")
}

func (p proxyHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Debugf("proxy handler was called for request to %s and headers %+v", r.URL.String(), internal.RedactRequestHeaders(r.Header))

	r.URL.Host = p.targetURL.Host     // copy target URL but not the URL path, only the host
	r.URL.Scheme = p.targetURL.Scheme // (and scheme because they get lost on the way)

	if isBackChannelLogoutRequest(r) {
		log.Debugf("Proxy: %s %s backchannel request found, logging out against sonar", r.Method, r.URL.String())
		p.casClient.Logout(w, r)
		r.URL.Path = p.logoutPath
		p.forwarder.ServeHTTP(w, r)
		return
	} else {
		log.Debugf("Proxy: %s %s backchannel request not found... continue with other stuff", r.Method, r.URL.String())
	}

	authenticationRequired := internal.IsAuthenticationRequired(r.URL.Path)
	if !authenticationRequired {
		log.Debugf("Proxy: %s request to %s does not need authentication", r.Method, r.URL.String())
		p.forwarder.ServeHTTP(w, r)
		return
	}

	// let everything-REST through
	if !IsBrowserRequest(r) {
		log.Debugf("Proxy: Found non-browser %s request to %s", r.Method, r.URL.String())
		p.forwarder.ServeHTTP(w, r)
		return
	}

	if !p.casAuthenticated(r) && r.URL.Path != "/sonar/api/authentication/logout" {
		log.Debugf("Proxy: Found non-authenticated %s request to %s", r.Method, r.URL.String())
		cas.RedirectToLogin(w, r)
		return
	}

	log.Debugf("proxy found authorized request to %s and headers %+v", r.URL.String(), internal.RedactRequestHeaders(r.Header))

	setHeaders(r, p.headers, p.adminGroupMapping)

	p.forwarder.ServeHTTP(w, r)
}

// setHeaders enriches a given request with SonarQube HTTP authorization headers.
func setHeaders(r *http.Request, headers authorizationHeaders, adminGroupMapping sonarAdminGroupMapping) {
	username := cas.Username(r)
	r.Header.Add(headers.Principal, username)

	attrs := cas.Attributes(r)
	r.Header.Add(headers.Name, attrs.Get("displayName"))
	r.Header.Add(headers.Mail, attrs.Get("mail"))
	// heads-up! do not use attrs.Get because it only returns the first group entry
	userGroups := strings.Join(attrs["groups"], ",") // delimited by comma according the sonar.properties commentary
	if isInAdminGroup(attrs["groups"], adminGroupMapping.cesAdminGroup) {
		userGroups += "," + adminGroupMapping.sonarAdminGroup
	}
	r.Header.Add(headers.Role, userGroups)

	if isInAdminGroup(attrs["groups"], adminGroupMapping.cesAdminGroup) {
		r.Header.Add(adminGroupMapping.sonarAdminGroup, adminGroupMapping.cesAdminGroup)
	}
	log.Debugf("Groups found to user %s: %s", username, userGroups)
}

func isInAdminGroup(currentGroups []string, cesAdminGroup string) bool {
	for _, currentGroup := range currentGroups {
		if currentGroup == cesAdminGroup {
			return true
		}
	}

	return false
}

func isBackChannelLogoutRequest(r *http.Request) bool {
	return r.Method == "POST" && (r.URL.Path == "/sonar/" || r.URL.Path == "/sonar")
}

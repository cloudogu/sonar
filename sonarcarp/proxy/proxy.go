package proxy

import (
	"fmt"
	"net/http"
	"net/url"
	"strings"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/cloudogu/sonar/sonarcarp/session"
	"github.com/op/go-logging"
	"github.com/vulcand/oxy/v2/forward"
)

var log = logging.MustGetLogger("proxy")

type sonarAdminGroupMapping struct {
	cesAdminGroup   string
	sonarAdminGroup string
}

// AuthorizationHeaders contain the mapping from config value to HTTP header name for SonarQube HTTP proxy authentication.
type AuthorizationHeaders struct {
	// Principal contains the user ID header name.
	Principal string
	// Role contains the user group header name.
	//
	// Even without group, SonarQube will assign the group "sonar-users" internally.
	Role string
	// Mail contains the user mail header name.
	Mail string
	// Name contains the user display name header name.
	Name string
}

type proxyHandler struct {
	targetURL         *url.URL
	forwarder         http.Handler
	casClient         *cas.Client
	headers           AuthorizationHeaders
	logoutPathUi      string
	logoutApiEndpoint string
	casAuthenticated  func(r *http.Request) bool
	adminGroupMapping sonarAdminGroupMapping
}

func CreateProxyHandler(headers AuthorizationHeaders, casClient *cas.Client, cfg config.Configuration) (http.Handler, error) {
	log.Debugf("creating proxy middleware")

	targetURL, err := url.Parse(cfg.ServiceUrl)
	if err != nil {
		return proxyHandler{}, fmt.Errorf("could not parse target url '%s': %w", cfg.ServiceUrl, err)
	}

	fwd := forward.New(true)

	pHandler := proxyHandler{
		targetURL:         targetURL,
		logoutPathUi:      cfg.LogoutPathFrontchannelEndpoint,
		logoutApiEndpoint: cfg.LogoutPathBackchannelEndpoint,
		forwarder:         fwd,
		casAuthenticated:  cas.IsAuthenticated,
		headers:           headers,
		adminGroupMapping: sonarAdminGroupMapping{cesAdminGroup: cfg.CesAdminGroup, sonarAdminGroup: cfg.SonarAdminGroup},
	}

	casHandlingProxy := casClient.CreateHandler(pHandler)

	return casHandlingProxy, nil
}

func (p proxyHandler) isFrontChannelLogoutRequest(r *http.Request) bool {
	// Clicking on logout performs a browser side redirect from the actual logout path back to index => Backend cannot catch the first request
	// So in that case we use the referrer to check if a request is a logout request.

	// TODO: is not this rather a || than a && situation? EITHER referer is ui logout OR URL goes right to logout API
	isFcLogout := strings.HasSuffix(r.Referer(), p.logoutPathUi) && strings.HasSuffix(r.URL.Path, p.logoutApiEndpoint)
	log.Debugf("is request a frontchannel logout? %t", isFcLogout)

	return isFcLogout
}

func IsBrowserRequest(req *http.Request) bool {
	lowerUserAgent := strings.ToLower(req.Header.Get("User-Agent"))
	return strings.Contains(lowerUserAgent, "mozilla") || strings.Contains(lowerUserAgent, "opera")
}

func (p proxyHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Debugf("proxy handler was called for request to %s and headers %+v", r.URL.String(), internal.RedactRequestHeaders(r.Header))

	if p.isFrontChannelLogoutRequest(r) {
		log.Debug("Proxy: Logout request")
		cas.RedirectToLogout(w, r)
		return
	}

	r.URL.Host = p.targetURL.Host     // copy target URL but not the URL path, only the host
	r.URL.Scheme = p.targetURL.Scheme // (and scheme because they get lost on the way)

	authenticationRequired := internal.IsInAlwaysAllowList(r.URL.Path)
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

	casUsername, casAttrs := getCasAttributes(r)

	saveJwtSessionForBackchannelLogout(r, casUsername)
	setHeaders(r, casUsername, casAttrs, p.headers, p.adminGroupMapping)

	p.forwarder.ServeHTTP(w, r)
}

func getCasAttributes(r *http.Request) (string, cas.UserAttributes) {
	username := cas.Username(r)
	attrs := cas.Attributes(r)
	return username, attrs
}

func saveJwtSessionForBackchannelLogout(r *http.Request, casUsername string) {
	session.SaveJwtTokensFor(casUsername, r.Cookies())
}

// setHeaders enriches a given request with SonarQube HTTP authorization headers.
func setHeaders(r *http.Request, casUsername string, casAttributes cas.UserAttributes, headers AuthorizationHeaders, adminGroupMapping sonarAdminGroupMapping) {
	r.Header.Add(headers.Principal, casUsername)
	r.Header.Add(headers.Name, casAttributes.Get("displayName"))
	r.Header.Add(headers.Mail, casAttributes.Get("mail"))
	// heads-up! do not use casAttributes.Get because it only returns the first group entry
	userGroups := strings.Join(casAttributes["groups"], ",") // delimited by comma according the sonar.properties commentary

	if isInAdminGroup(casAttributes["groups"], adminGroupMapping.cesAdminGroup) {
		userGroups += "," + adminGroupMapping.sonarAdminGroup
	}
	r.Header.Add(headers.Role, userGroups)

	if isInAdminGroup(casAttributes["groups"], adminGroupMapping.cesAdminGroup) {
		r.Header.Add(adminGroupMapping.sonarAdminGroup, adminGroupMapping.cesAdminGroup)
	}

	log.Debugf("Groups found to user %s: %s", casUsername, userGroups)
}

func isInAdminGroup(currentGroups []string, cesAdminGroup string) bool {
	for _, currentGroup := range currentGroups {
		if currentGroup == cesAdminGroup {
			return true
		}
	}

	return false
}

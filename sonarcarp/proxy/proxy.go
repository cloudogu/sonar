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

type proxyHandler struct {
	targetURL         *url.URL
	forwarder         http.Handler
	headers           AuthorizationHeaders
	logoutPathUi      string
	logoutApiEndpoint string
	adminGroupMapping sonarAdminGroupMapping
	casClient         casClient
}

func CreateProxyHandler(headers AuthorizationHeaders, cfg config.Configuration) (*proxyHandler, error) {
	log.Debugf("creating proxy middleware")

	targetURL, err := url.Parse(cfg.ServiceUrl)
	if err != nil {
		return &proxyHandler{}, fmt.Errorf("could not parse target url '%s': %w", cfg.ServiceUrl, err)
	}

	fwd := forward.New(true)

	pHandler := &proxyHandler{
		targetURL:         targetURL,
		logoutPathUi:      cfg.LogoutPathFrontchannelEndpoint,
		logoutApiEndpoint: cfg.LogoutPathBackchannelEndpoint,
		forwarder:         fwd,
		headers:           headers,
		adminGroupMapping: sonarAdminGroupMapping{cesAdminGroup: cfg.CesAdminGroup, sonarAdminGroup: cfg.SonarAdminGroup},
		casClient:         &casClientAbstracter{},
	}

	return pHandler, nil
}

func (p *proxyHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Debugf("proxy handler was called for request to %s and headers %+v", r.URL.String(), internal.RedactRequestHeaders(r.Header))

	if p.isFrontChannelLogoutRequest(r) {
		log.Debug("Proxy: Logout request")
		p.casClient.RedirectToLogout(w, r)
		return
	}

	r.URL.Host = p.targetURL.Host     // copy target URL but not the URL path, only the host
	r.URL.Scheme = p.targetURL.Scheme // (and scheme because they get lost on the way)

	noAuthenticationRequired := internal.IsInAlwaysAllowList(r.URL.Path)
	if noAuthenticationRequired {
		log.Debugf("Proxy: %s request to %s does not need authentication", r.Method, r.URL.String())
		p.forwarder.ServeHTTP(w, r)
		return
	}

	// let everything-REST through
	if !internal.IsBrowserRequest(r) {
		log.Debugf("Proxy: Found non-browser %s request to %s", r.Method, r.URL.String())
		p.forwarder.ServeHTTP(w, r)
		return
	}

	if !p.casClient.IsAuthenticated(r) && r.URL.Path != "/sonar/api/authentication/logout" {
		log.Debugf("Proxy: Found non-authenticated %s request to %s", r.Method, r.URL.String())
		p.casClient.RedirectToLogin(w, r)
		return
	}

	log.Debugf("proxy found authorized request to %s and headers %+v", r.URL.String(), internal.RedactRequestHeaders(r.Header))

	casUsername, casAttrs := p.getCasAttributes(r)

	saveJwtSessionForBackchannelLogout(r, casUsername)
	setHeaders(r, casUsername, casAttrs, p.headers, p.adminGroupMapping)

	p.forwarder.ServeHTTP(w, r)
}

func (p *proxyHandler) isFrontChannelLogoutRequest(r *http.Request) bool {
	// Clicking on logout performs a browser side redirect from the actual logout path back to index => Backend cannot catch the first request
	// So in that case we use the referrer to check if a request is a logout request.

	// TODO: is not this rather a || than a && situation? EITHER referer is ui logout OR URL goes right to logout API
	isFcLogout := strings.HasSuffix(r.Referer(), p.logoutPathUi) && strings.HasSuffix(r.URL.Path, p.logoutApiEndpoint)
	log.Debugf("is request a frontchannel logout? %t", isFcLogout)

	return isFcLogout
}

func (p *proxyHandler) getCasAttributes(r *http.Request) (string, cas.UserAttributes) {
	username := p.casClient.Username(r)
	attrs := p.casClient.Attributes(r)
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
	userGroups := strings.Join(casAttributes["groups"], ",")

	splitCasGroups := strings.Split(userGroups, ",")
	if isInAdminGroup(splitCasGroups, adminGroupMapping.cesAdminGroup) {
		// groups are delimited by comma according the sonar.properties commentary
		userGroups += "," + adminGroupMapping.sonarAdminGroup
	}
	r.Header.Add(headers.Role, userGroups)

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

type casClientAbstracter struct{}

func (cca *casClientAbstracter) RedirectToLogin(w http.ResponseWriter, r *http.Request) {
	cas.RedirectToLogin(w, r)
}

// RedirectToLogout allows CAS protected handlers to redirect a request to the CAS logout page.
func (cca *casClientAbstracter) RedirectToLogout(w http.ResponseWriter, r *http.Request) {
	cas.RedirectToLogout(w, r)
}

// Username returns a CAS username to a CAS session cookie from the given request.
func (cca *casClientAbstracter) Username(r *http.Request) string {
	return cas.Username(r)
}

// Attributes returns other CAS user attributes to a CAS session cookie from the given request.
func (cca *casClientAbstracter) Attributes(r *http.Request) cas.UserAttributes {
	return cas.Attributes(r)
}

// IsAuthenticated returns whether a request indicates if the request's user is CAS authenticated.
func (cca *casClientAbstracter) IsAuthenticated(r *http.Request) bool {
	return cas.IsAuthenticated(r)
}

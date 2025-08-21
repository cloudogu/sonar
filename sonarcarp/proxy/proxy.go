package proxy

import (
	"fmt"
	"net/http"
	"net/url"
	"strings"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/vulcand/oxy/v2/forward"
)

type unauthorizedServer interface {
	ServeUnauthorized(writer http.ResponseWriter, req *http.Request)
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
	unauthorizedServer    unauthorizedServer
	casClient             *cas.Client
	headers               authorizationHeaders
	logoutPath            string
	logoutRedirectionPath string
	casAuthenticated      func(r *http.Request) bool
}

func createProxyHandler(sTargetURL string, headers authorizationHeaders, casClient *cas.Client, logoutPath string, logoutRedirectionPath string) (http.Handler, error) {
	log.Debugf("creating proxy middleware")

	targetURL, err := url.Parse(sTargetURL)
	if err != nil {
		return proxyHandler{}, fmt.Errorf("could not parse target url '%s': %w", sTargetURL, err)
	}

	fwd := forward.New(true)

	pHandler := proxyHandler{
		targetURL:             targetURL,
		forwarder:             fwd,
		casAuthenticated:      cas.IsAuthenticated,
		headers:               headers,
		logoutPath:            logoutPath,
		logoutRedirectionPath: logoutRedirectionPath,
	}

	return casClient.CreateHandler(pHandler), nil
}

func (p proxyHandler) isLogoutRequest(r *http.Request) bool {
	// Clicking on logout performs a browser side redirect from the actual logout path back to index => Backend cannot catch the first request
	// So in that case we use the referrer to check if a request is a logout request.
	return strings.HasSuffix(r.Referer(), p.logoutPath) && r.URL.Path == p.logoutRedirectionPath
}

func (p proxyHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if p.isLogoutRequest(r) {
		cas.RedirectToLogout(w, r)
		return
	}

	if !p.casAuthenticated(r) && r.URL.Path != "/sonar/api/authentication/logout" {
		cas.RedirectToLogin(w, r)
		return
	}

	log.Debugf("proxy found authorized request to %s and headers %+v", r.URL.String(), internal.RedactRequestHeaders(r.Header))

	r.URL.Host = p.targetURL.Host     // copy target URL but not the URL path, only the host
	r.URL.Scheme = p.targetURL.Scheme // (and scheme because they get lost on the way)

	setHeaders(r, p.headers)

	p.forwarder.ServeHTTP(w, r)
}

// setHeaders enriches a given request with SonarQube HTTP authorization headers.
func setHeaders(r *http.Request, headers authorizationHeaders) {
	r.Header.Add(headers.Principal, cas.Username(r))

	attrs := cas.Attributes(r)
	r.Header.Add(headers.Name, attrs.Get("displayName"))
	r.Header.Add(headers.Mail, attrs.Get("mail"))
	r.Header.Add(headers.Role, attrs.Get("groups"))
}

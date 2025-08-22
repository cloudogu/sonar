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

func IsBrowserRequest(req *http.Request) bool {
	return isBrowserUserAgent(req.Header.Get("User-Agent")) || isBackChannelLogoutRequest()(req)
}

func isBrowserUserAgent(userAgent string) bool {
	lowerUserAgent := strings.ToLower(userAgent)
	return strings.Contains(lowerUserAgent, "mozilla") || strings.Contains(lowerUserAgent, "opera")
}

func (p proxyHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Debugf("1")
	if !IsBrowserRequest(r) {
		log.Debugf("1.1")
		p.forwarder.ServeHTTP(w, r)
		return
	}

	log.Debugf("2")
	if p.isLogoutRequest(r) {
		log.Debugf("2.1")
		cas.RedirectToLogout(w, r)
		return
	}

	log.Debugf("3")
	if !p.casAuthenticated(r) && r.URL.Path != "/sonar/api/authentication/logout" {
		log.Debugf("3.1")
		cas.RedirectToLogin(w, r)
		return
	}

	log.Debugf("4")

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

package proxy

import (
	"bytes"
	"fmt"
	"io"
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

	casHandledProxyHandler := casClient.CreateHandler(pHandler)

	return casHandledProxyHandler, nil
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
	log.Debugf("proxy handler was called for request to %s and headers %+v", r.URL.String(), internal.RedactRequestHeaders(r.Header))

	serveHTTPAndHandleStatusCode(func(writer http.ResponseWriter, request *http.Request) {
		origReqUrl := request.URL.String()
		log.Debugf("proxy status handler was called for %s", origReqUrl)

		r.URL.Host = p.targetURL.Host     // copy target URL but not the URL path, only the host
		r.URL.Scheme = p.targetURL.Scheme // (and scheme because they get lost on the way)

		tempRespWriter := newBufferWriter()

		// erzeuge response writer buffer
		// führe ServeHTTP gegen Proxy(direkt SonarQube) aus
		// untersuche response status code
		// if statuscode == 401 frage CAS nach Auth
		// if immer noch unauth brich request ab
		// else reichere Request mit Headern an # zwingend: nur wenn CAS dies erlaubt, nicht bei sonstigen requests
		//      führe ServeHTTP gegen Proxy(direkt SonarQube) aus

		p.forwarder.ServeHTTP(tempRespWriter, request)

		log.Debugf("Response for %s returned with HTTP %d", origReqUrl, srw.httpStatusCode)
		if tempRespWriter.statusCode == http.StatusUnauthorized {
			log.Debug("Sending another request to CAS instead")
			if !p.casAuthenticated(request) {
				w.WriteHeader(http.StatusUnauthorized)
				var denyContent []byte
				_, err := tempRespWriter.Read(denyContent)
				if err != nil {
					log.Errorf("Error reading deny response from CAS proxy: %s", err.Error())
				}
				_, err = w.Write(denyContent)
				if err != nil {
					log.Errorf("Error reading deny response from CAS proxy: %s", err.Error())
				}
				return
			}

			log.Infof("CAS replied request %s was authenticated. Forwarding with headers", origReqUrl)
			//tempRespWriter = newBufferWriter() // TODO
			setHeaders(request, p.headers)
			p.forwarder.ServeHTTP(writer, request)
		}

		// let everything-REST through
		if !IsBrowserRequest(r) {
			log.Debugf("========= Request is not a browser request: Happy unauthorized requesting!!!1!")
			p.forwarder.ServeHTTP(w, r)
			return
		}

		if p.isLogoutRequest(r) {
			log.Debugf("========= Request is a logout request")
			cas.RedirectToLogout(w, r)
			return
		}

		if !p.casAuthenticated(r) && r.URL.Path != "/sonar/api/authentication/logout" {
			log.Debugf("========= Request is a not CAS authenticated... redirecting")
			cas.RedirectToLogin(w, r)
			return
		}

		// Proxyticketing
		// user -tue etwas für mich-> user-agent -dial 192.168.56.2/sonar/-> sonarcarp -copy request-> sonarqube "kennst du den?"
		//                                                                   sonarcarp <-response- sonarqube "nööö kenne ich nicht"
		//                                                                   sonarcarp -CAS help plz?-> CAS "kennst du den?"
		//                                                                   sonarcarp <-i help!- CAS "yoo, kenne ich!"
		//                                                                   sonarcarp -copy request mit neuen Auth-Headern-> sonarqube

		// Rest-Call
		// user -tue etwas für mich-> user-agent -dial 192.168.56.2/sonar/-> sonarcarp -copy request-> sonarqube "kennst du den?"
		// user <-ergebnis- user-agent <-response- sonarcarp <-response- sonarqube "nööö kenne ich nicht"

		log.Debug("Regular request found. Adding authentication information...")
		setHeaders(r, p.headers)
		p.forwarder.ServeHTTP(w, r)
	}).ServeHTTP(w, r)
}

// setHeaders enriches a given request with SonarQube HTTP authorization headers.
func setHeaders(r *http.Request, headers authorizationHeaders) {
	r.Header.Add(headers.Principal, cas.Username(r))

	attrs := cas.Attributes(r)
	r.Header.Add(headers.Name, attrs.Get("displayName"))
	r.Header.Add(headers.Mail, attrs.Get("mail"))
	r.Header.Add(headers.Role, attrs.Get("groups"))
}

// newBufferWriter creates a new http.ResponseWriter which may be conditionally written back to the client.
//
// This makes sense when analyzing and acting on proxied requests where the original response must not be written
// immediately but a different response depending on another action (f. i. a CAS response).
func newBufferWriter() *BufferWriter {
	buffer := &bytes.Buffer{}
	return &BufferWriter{
		buffer:     buffer,
		statusCode: http.StatusOK,
		//H:      make(http.Header),
	}
}

// BufferWriter buffer writer.
type BufferWriter struct {
	statusCode int
	buffer     io.ReadWriter
}

// Close closes the writer.
func (b *BufferWriter) Close() error {
	return nil
}

// Header gets response header.
func (b *BufferWriter) Header() http.Header {
	panic("not implemented")
}

func (b *BufferWriter) Write(buf []byte) (int, error) {
	return b.buffer.Write(buf)
}

// WriteHeader writes status code.
func (b *BufferWriter) WriteHeader(code int) {
	b.statusCode = code
}

// Read reads up to len(p) bytes into p. It returns the number of bytes
// read (0 <= n <= len(p)) and any error encountered.
func (b *BufferWriter) Read(p []byte) (int, error) {
	return b.buffer.Read(p)
}

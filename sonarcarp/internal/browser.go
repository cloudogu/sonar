package internal

import (
	"net/http"
)

// IsBrowserRequest reports whether req likely originated from an interactive
// browser rather than a non-interactive client.
//
// Rationale
// Many machine-to-machine calls send an Authorization header (e.g., Bearer,
// Basic). Typical browser navigations don’t. This makes absence of
// Authorization a decent (but imperfect) signal for “browser-ish” traffic.
//
// Important caveat: CAS back-channel logout
// Apereo CAS back-channel logout callbacks are server-to-server requests that
// typically:
//   - do NOT include an "Authorization" header, and
//   - use a non-browser User-Agent (often an Apache/HttpClient variant), and
//   - post an XML logout message to your endpoint.
//
// These requests are NOT browser requests, but need to be considered to use the
// logout process of the underlying go-cas client.
//
// Returns
//
//	true  — request has no Authorization header (likely browser, but see caveat)
//	false — request has an Authorization header (likely non-browser)
func IsBrowserRequest(req *http.Request) bool {
	return req.Header.Get("Authorization") == ""
}

package internal

import (
	"net/http"
	"path"
)

// WithBackChannelLogoutRequestCheck returns a predicate that reports whether an
// incoming *http.Request is a CAS back-channel logout callback for the
// given application context path.
//
// A CAS back-channel logout is a server-to-server POST that the CAS server
// sends to your application (no browser involved). This predicate identifies
// such requests using three signals:
//
//  1. Method must be POST
//  2. Content-Type must be "application/x-www-form-urlencoded"
//  3. Request URL path must equal appContextPath (with or without a trailing slash)
//
// The supplied appContextPath is normalized via path.Join so that both
// "/app" and "/app/" are treated consistently. The predicate then accepts:
//
//   - exact match:           /app
//   - match with trailing /: /app/
//
// Returns
//
//	true  — the request matches all checks and is likely a CAS back-channel logout
//	false — otherwise
//
// Notes
//   - The check does not inspect the POST body for a CAS logout payload; it is a
//     lightweight heuristic based on method, content type, and path so body is not accidentally read.
func WithBackChannelLogoutRequestCheck(appContextPath string) func(r *http.Request) bool {
	sanitizedAppContextPath := path.Join(appContextPath)

	return func(r *http.Request) bool {
		if r.Method != http.MethodPost {
			return false
		}

		contentType := r.Header.Get("Content-Type")
		if contentType != "application/x-www-form-urlencoded" {
			return false
		}

		urlPath := r.URL.Path

		if !(urlPath == sanitizedAppContextPath || urlPath == sanitizedAppContextPath+"/") {
			return false
		}

		return true
	}
}

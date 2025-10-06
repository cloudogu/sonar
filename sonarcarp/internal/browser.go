package internal

import (
	"net/http"
	"strings"
)

// IsBrowserRequest returns true if the request origins from a browser and not any other HTTP client.
func IsBrowserRequest(req *http.Request) bool {
	lowerUserAgent := strings.ToLower(req.Header.Get("User-Agent"))

	return strings.Contains(lowerUserAgent, "mozilla") || strings.Contains(lowerUserAgent, "opera")
}

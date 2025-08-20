package internal

import (
	"net/http"
	"strings"
)

// RedactRequestHeaders returns a copy of the request headers without security critical header information (like
// cookies etc.) so they can be printed into debug logs without jeopardizing the user's data.
func RedactRequestHeaders(original http.Header) http.Header {
	redacted := http.Header{}
	for key, values := range original {
		switch strings.ToLower(key) {
		case "cookies":
			continue
		case "authorization":
			continue
		default:
			redacted[key] = append(redacted[key], values...)
		}
	}

	return redacted
}

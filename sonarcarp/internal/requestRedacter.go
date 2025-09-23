package internal

import (
	"net/http"
	"strings"

	"github.com/op/go-logging"
)

var log = logging.MustGetLogger("internal")

// RedactRequestHeaders returns a copy of the request headers without security critical header information (like
// cookies etc.) so they can be printed into debug logs without jeopardizing the user's data.
func RedactRequestHeaders(original http.Header) http.Header {
	redacted := http.Header{}
	// set to true during debugging to log sensitive auth data
	const allowSensitiveValues = false
	if allowSensitiveValues {
		log.Debug("Redacting headers deactivated. DO NOT USE IN PRODUCTION!")
		return original
	}

	log.Debug("Return redacted headers")

	for key, values := range original {
		switch strings.ToLower(key) {
		case "cookie":
			fallthrough
		case "set-cookie":
			fallthrough
		case "authorization":
			redacted[key] = append(redacted[key], "[Redacted]")
		default:
			redacted[key] = append(redacted[key], values...)
		}
	}

	return redacted
}

package session

import (
	"net/http"
)

// casClient extracts static go-cas functions into testable functions.
type casClient interface {
	// Logout terminates the current user's CAS session
	Logout(w http.ResponseWriter, r *http.Request)
}

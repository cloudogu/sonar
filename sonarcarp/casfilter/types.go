package casfilter

import (
	"net/http"
)

// casBrowserClient extracts static go-cas functions into testable functions.
type casBrowserClient interface {
	Handle(nextHandler http.Handler) http.Handler
}

// casBrowserClient extracts static go-cas functions into testable functions.
type casRestClient interface {
	HandleFunc(nextHandler func(w http.ResponseWriter, r *http.Request)) http.Handler
}

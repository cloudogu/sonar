package casfilter

import (
	"net/http"

	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/op/go-logging"
)

var log = logging.MustGetLogger("casfilter")

func Middleware(casBrowserClient casBrowserClient, casRestClient casRestClient, next http.Handler) http.Handler {
	log.Debugf("creating cas middleware")

	casBrowserHandler := casBrowserClient.Handle(next)
	casRestHandler := casRestClient.HandleFunc(next.ServeHTTP)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Debugf("cas middleware was called with request %s", r.URL.String())

		if internal.IsBrowserRequest(r) {
			log.Debug("Request is browser request")
			casBrowserHandler.ServeHTTP(w, r)
			return
		}

		log.Debugf("Request is REST request")

		casRestHandler.ServeHTTP(w, r)
	})
}

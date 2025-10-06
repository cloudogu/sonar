package casfilter

import (
	"net/http"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/op/go-logging"
)

var log = logging.MustGetLogger("cas")

func Middleware(casBrowserClient *cas.Client, casRestClient *cas.RestClient, next http.Handler) http.Handler {
	log.Debugf("creating proxy middleware")

	casBrowserHandler := casBrowserClient.CreateHandler(next)
	casRestHandler := casRestClient.HandleFunc(next.ServeHTTP)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Debugf("cas middleware was called with request %s", r.URL.String())

		if internal.IsBrowserRequest(r) {
			log.Debugf("Request is browser request")
			casBrowserHandler.ServeHTTP(w, r)
			return
		}

		log.Debugf("Request is REST request")

		casRestHandler.ServeHTTP(w, r)
	})
}

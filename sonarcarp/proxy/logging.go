package proxy

import (
	"bufio"
	"fmt"
	"net"
	"net/http"
)

type statusResponseWriter struct {
	http.ResponseWriter
	httpStatusCode int
}

func (s *statusResponseWriter) WriteHeader(code int) {
	s.httpStatusCode = code
	s.ResponseWriter.WriteHeader(code)
}

// Hijack enables support for websockets
func (s *statusResponseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	h, ok := s.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, fmt.Errorf("hijacker is not implemented")
	}

	return h.Hijack()
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		srw := &statusResponseWriter{
			ResponseWriter: writer,
			httpStatusCode: http.StatusOK,
		}

		next.ServeHTTP(srw, request)

		log.Infof("%d %s %s", srw.httpStatusCode, request.Method, request.URL.Path)
		if srw.httpStatusCode >= 300 {
			log.Infof("request headers: %#v", srw.Header())
		}
	})
}

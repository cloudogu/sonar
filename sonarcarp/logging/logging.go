package logging

import (
	"bufio"
	"fmt"
	"net"
	"net/http"

	"github.com/op/go-logging"

	"github.com/cloudogu/sonar/sonarcarp/internal"
)

var log = logging.MustGetLogger("logging")

func NewStatusResponseWriter(respWriter http.ResponseWriter) *StatusResponseWriter {
	return &StatusResponseWriter{
		writer:         respWriter,
		httpStatusCode: http.StatusOK,
	}
}

// StatusResponseWriter acts like a regular HTTP middleware but also issues logs on certain log levels or status codes.
// Besides that, StatusResponseWriter does not alter the request/response behavior in any way.
type StatusResponseWriter struct {
	writer         http.ResponseWriter
	httpStatusCode int
}

func (srw *StatusResponseWriter) Header() http.Header {
	return srw.writer.Header()
}

func (srw *StatusResponseWriter) Write(bytes []byte) (int, error) {
	return srw.writer.Write(bytes)
}

func (srw *StatusResponseWriter) HttpStatusCode() int {
	return srw.httpStatusCode
}

// WriteHeader saves the status code for later use and then sends an HTTP response header with the provided status code.
func (srw *StatusResponseWriter) WriteHeader(code int) {
	//debug.PrintStack()

	srw.httpStatusCode = code
	srw.writer.WriteHeader(code)
}

// Hijack enables support for websockets
func (srw *StatusResponseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	h, ok := srw.writer.(http.Hijacker)
	if !ok {
		return nil, nil, fmt.Errorf("http websocket connector/hijacker is not implemented")
	}

	return h.Hijack()
}

// Middleware creates a delegate ResponseWriter that saves the HTTP status code for post-response purposes.
//
// Also, the StatusResponseWriter logs request information (without body and sensitive headers) in INFO log level,
// and response information (without body and sensitive headers) in DEBUG log level.
func Middleware(next http.Handler, handlerName string) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		log.Debugf("Middleware(%s) was called for %s", handlerName, request.URL.String())
		srw := &StatusResponseWriter{
			writer:         writer,
			httpStatusCode: http.StatusOK, // this value will be overwritten during ServerHTTP() calling WriteHeader()
		}

		next.ServeHTTP(srw, request)

		log.Infof("%d %s %s", srw.httpStatusCode, request.Method, request.URL.Path)
		if srw.httpStatusCode >= 300 {
			log.Debugf("Response headers: %#v", internal.RedactRequestHeaders(srw.Header()))
		}
	})
}

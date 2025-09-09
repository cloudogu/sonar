package logging

import (
	"bufio"
	"fmt"
	"net"
	"net/http"

	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/op/go-logging"
)

var log = logging.MustGetLogger("logging")

func NewStatusResponseWriter(respWriter http.ResponseWriter, r *http.Request, s string) *StatusResponseWriter {
	return &StatusResponseWriter{
		writer:         respWriter,
		httpStatusCode: http.StatusOK,
		r:              r,
		id:             fmt.Sprintf("req%p:wr%p", r, respWriter),
		usage:          s,
	}
}

// StatusResponseWriter acts like a regular HTTP middleware but also issues logs on certain log levels or status codes.
// Besides that, StatusResponseWriter does not alter the request/response behavior in any way.
type StatusResponseWriter struct {
	writer         http.ResponseWriter
	httpStatusCode int
	r              *http.Request
	id             string
	usage          string
}

func (srw *StatusResponseWriter) Header() http.Header {
	log.Errorf("===== Some asked for the headers for %s", srw.r.URL.String())
	return srw.writer.Header()
}

func (srw *StatusResponseWriter) Write(bytes []byte) (int, error) {
	log.Errorf("===== writing %s bytes %s\n", srw.usage, srw.r.URL.String())
	//log.Error("%s", string(debug.Stack()))
	write, err := srw.writer.Write(bytes)
	log.Errorf("===== end %s Write()", srw.usage)
	return write, err
}

func (srw *StatusResponseWriter) HttpStatusCode() int {
	return srw.httpStatusCode
}

// WriteHeader saves the status code for later use and then sends an HTTP response header with the provided status code.
func (srw *StatusResponseWriter) WriteHeader(code int) {
	log.Errorf("===== writing header code %d for %s %s\n", code, srw.r.Method, srw.r.URL.String())
	//log.Errorf("===== %s %s was asked by %s ; %#v\n", srw.r.Method, srw.r.URL.String(), srw.r.UserAgent(), srw.r.Header)
	//log.Error("%s", string(debug.Stack()))

	srw.httpStatusCode = code
	srw.writer.WriteHeader(code)
	log.Errorf("===== %s end WriteHeader() for %s\n", srw.usage, srw.r.URL.String())
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
		// TODO replace with constructor
		srw := &StatusResponseWriter{
			r:              request,
			writer:         writer,
			httpStatusCode: http.StatusOK, // this value will be overwritten during ServerHTTP() calling WriteHeader()
			id:             fmt.Sprintf("%p:%p", request, writer),
			usage:          "logger",
		}

		next.ServeHTTP(srw, request)

		log.Infof("%d %s %s", srw.httpStatusCode, request.Method, request.URL.Path)
		if srw.httpStatusCode >= 300 {
			log.Debugf("Response headers: %#v", internal.RedactRequestHeaders(srw.Header()))
		}
	})
}

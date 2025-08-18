package proxy

import (
	"embed"
	"fmt"
	"io/fs"
	"net/http"
)

//go:embed public
var content embed.FS

func createStaticFileHandler() (staticHandler, error) {
	publicFileDir, err := fs.Sub(content, "public")
	if err != nil {
		return staticHandler{}, fmt.Errorf("could not read subdir public: %w", err)
	}

	return staticHandler{
		publicFileDir: publicFileDir,
		fileServer:    http.FileServerFS(content),
		serveFileFunc: http.ServeFileFS,
	}, nil
}

type staticHandler struct {
	publicFileDir fs.FS
	fileServer    http.Handler
	serveFileFunc func(w http.ResponseWriter, r *http.Request, fsys fs.FS, name string)
}

func (s staticHandler) ServeHTTP(writer http.ResponseWriter, req *http.Request) {
	s.fileServer.ServeHTTP(writer, req)
}

func (s staticHandler) ServeUnauthorized(writer http.ResponseWriter, req *http.Request) {
	writer.WriteHeader(http.StatusUnauthorized)
	s.serveFileFunc(writer, req, s.publicFileDir, "401.html")
}

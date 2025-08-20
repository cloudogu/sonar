package proxy

import (
	"github.com/cloudogu/sonar/sonarcarp/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestServeHttp(t *testing.T) {
	h := &mocks.Handler{}
	h.On("ServeHTTP", mock.Anything, mock.Anything).Once()
	handler := staticHandler{
		fileServer: h,
	}

	handler.ServeHTTP(nil, nil)

	h.AssertExpectations(t)
}

func TestStaticHandler_ServeUnauthorized(t *testing.T) {

	mw := httptest.NewRecorder()

	handler := staticHandler{
		publicFileDir: nil,
		serveFileFunc: func(w http.ResponseWriter, r *http.Request, fsys fs.FS, name string) {
			assert.Equal(t, "401.html", name)
		},
	}

	handler.ServeUnauthorized(mw, nil)

	assert.Equal(t, http.StatusUnauthorized, mw.Code)
}

package logging

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cloudogu/sonar/sonarcarp/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

func TestStatusResponseWriter_WriteHeader(t *testing.T) {
	rwMock := httptest.NewRecorder()

	sw := StatusResponseWriter{
		writer:         rwMock,
		httpStatusCode: 0,
	}

	sw.WriteHeader(200)

	assert.Equal(t, 200, sw.httpStatusCode)

	assert.Equal(t, 200, rwMock.Code)
}

func TestLoggingMiddleware(t *testing.T) {
	mh := &mocks.Handler{
		MserveHTTP: func(w http.ResponseWriter, r *http.Request) {
			_, ok := w.(http.Hijacker)
			assert.True(t, ok)
		},
	}

	mh.On("ServeHTTP", mock.Anything, mock.Anything)

	lm, reset := mocks.CreateLoggingMock(log)
	defer reset()

	h := Middleware(mh, "testlogging")

	mw := httptest.NewRecorder()
	req, err := http.NewRequest(http.MethodGet, "testURL", nil)
	require.NoError(t, err)

	h.ServeHTTP(mw, req)

	assert.Equal(t, 1, lm.InfoCalls)

	mh.AssertCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
	mh.AssertExpectations(t)
}

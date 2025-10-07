package proxy

import (
	"github.com/cloudogu/sonarcarp/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestStatusResponseWriter_WriteHeader(t *testing.T) {
	rwMock := httptest.NewRecorder()

	sw := statusResponseWriter{
		ResponseWriter: rwMock,
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

	h := loggingMiddleware(mh)

	mw := httptest.NewRecorder()
	req, err := http.NewRequest(http.MethodGet, "testURL", nil)
	require.NoError(t, err)

	h.ServeHTTP(mw, req)

	assert.Equal(t, 1, lm.InfoCalls)

	mh.AssertCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
	mh.AssertExpectations(t)
}

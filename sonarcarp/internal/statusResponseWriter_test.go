package internal

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

func TestStatusResponseWriter_Write(t *testing.T) {
	t.Run("should use the underlying writer", func(t *testing.T) {
		// given
		rwMock := httptest.NewRecorder()

		sut := StatusResponseWriter{writer: rwMock}

		// when
		actualInt, err := sut.Write([]byte("hello"))

		// then
		require.NoError(t, err)
		assert.Equal(t, 5, actualInt)
		assert.Equal(t, "hello", rwMock.Body.String())
	})
}

func TestStatusResponseWriter_HttpStatusCode(t *testing.T) {
	sut := StatusResponseWriter{}
	sut.httpStatusCode = http.StatusTeapot

	assert.Equal(t, http.StatusTeapot, sut.HttpStatusCode())
}

func TestStatusResponseWriter_Header(t *testing.T) {
	// given
	rwMock := httptest.NewRecorder()
	sut := StatusResponseWriter{writer: rwMock}

	// when
	sut.Header().Add("X-A", "value")

	// then
	assert.Equal(t, "value", rwMock.Header().Get("X-A"))
}

func TestStatusResponseWriter_Hijack(t *testing.T) {
	t.Run("should return not-implemented error", func(t *testing.T) {
		// given
		rwMock := httptest.NewRecorder()
		sut := StatusResponseWriter{writer: rwMock}

		// when
		_, _, err := sut.Hijack()

		// then
		require.Error(t, err)
		assert.ErrorContains(t, err, "http websocket connector/hijacker is not implemented")
	})
}

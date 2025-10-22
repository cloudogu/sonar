package casfilter

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

func TestMiddleware(t *testing.T) {
	t.Run("cas browser client handles browser request", func(t *testing.T) {
		var next = toHandler(func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusOK)
		})

		casBrowserHandler := new(handlerMock)
		casBrowserHandler.On("ServeHTTP", mock.Anything, mock.Anything).Return()

		casBrowserMock := newMockCasBrowserClient(t)
		casBrowserMock.EXPECT().Handle(mock.Anything).Return(casBrowserHandler)
		casRestMock := newMockCasRestClient(t)
		casRestMock.EXPECT().HandleFunc(mock.Anything).Return(nil) // this one will not be used for browser requests

		sut := Middleware(casBrowserMock, casRestMock, next)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			sut.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer server.Close()

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		req.Header.Add("User-Agent", "Mozilla Firefox something something Gecko something")
		require.NoError(t, err)

		// when
		resp, lErr := server.Client().Do(req)

		// then
		assert.NoError(t, lErr)
		assert.Equal(t, http.StatusOK, resp.StatusCode)
		casBrowserHandler.AssertExpectations(t)
	})
	t.Run("cas rest client handles request with authorization header", func(t *testing.T) {
		var next = toHandler(func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusOK)
		})

		casRestHandler := new(handlerMock)
		casRestHandler.On("ServeHTTP", mock.Anything, mock.Anything).Return()

		casBrowserMock := newMockCasBrowserClient(t)
		casBrowserMock.EXPECT().Handle(mock.Anything).Return(nil) // this one will not be used for Rest calls
		casRestMock := newMockCasRestClient(t)
		casRestMock.EXPECT().HandleFunc(mock.Anything).Return(casRestHandler)

		sut := Middleware(casBrowserMock, casRestMock, next)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			sut.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer server.Close()

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		// no user agent here
		require.NoError(t, err)

		req.Header.Set("Authorization", "testValue")

		// when
		resp, lErr := server.Client().Do(req)

		// then
		assert.NoError(t, lErr)
		assert.Equal(t, http.StatusOK, resp.StatusCode)
		casRestHandler.AssertExpectations(t)
	})
}

type handlerMock struct {
	mock.Mock
}

func (h *handlerMock) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	h.Called(writer, request)
}

func toHandler(handler func(writer http.ResponseWriter, request *http.Request)) http.Handler {
	return http.HandlerFunc(handler)
}

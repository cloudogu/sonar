package proxy

import (
	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonarcarp/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

func TestCreateProxyHandler(t *testing.T) {
	t.Run("create handler", func(t *testing.T) {
		targetURL := "testURL"

		handler, err := createProxyHandler(targetURL, authorizationHeaders{}, &cas.Client{}, "", "")

		assert.NoError(t, err)
		assert.NotNil(t, handler)
	})

	t.Run("invalid url", func(t *testing.T) {
		middlewareMock1 := newMockMiddleware(t)
		middlewareMock2 := newMockMiddleware(t)
		middlewareMock3 := newMockMiddleware(t)

		invalidTargetURL := ":example.com"

		_, err := createProxyHandler(invalidTargetURL, authorizationHeaders{}, nil, "", "")

		middlewareMock1.AssertNotCalled(t, "Execute", mock.Anything)
		middlewareMock2.AssertNotCalled(t, "Execute", mock.Anything)
		middlewareMock3.AssertNotCalled(t, "Execute", mock.Anything)

		assert.Error(t, err)
	})
}

func TestProxyHandler_ServeHTTP(t *testing.T) {
	t.Run("ServeHTTP", func(t *testing.T) {
		tUrl, err := url.Parse("testURL")
		require.NoError(t, err)

		aChecker := newMockAuthorizationChecker(t)
		uServer := newMockUnauthorizedServer(t)

		fwdMock := &mocks.Handler{
			MserveHTTP: func(w http.ResponseWriter, r *http.Request) {
				assert.Equal(t, tUrl, r.URL)
			},
		}

		fwdMock.On("ServeHTTP", mock.Anything, mock.Anything)

		aChecker.EXPECT().IsAuthorized(mock.Anything).Return(true)

		ph := proxyHandler{
			targetURL:            tUrl,
			forwarder:            fwdMock,
			unauthorizedServer:   uServer,
			authorizationChecker: aChecker,
		}

		req, err := http.NewRequest(http.MethodGet, "otherURL", nil)
		require.NoError(t, err)

		ph.ServeHTTP(httptest.NewRecorder(), req)

		fwdMock.AssertCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
		fwdMock.AssertExpectations(t)
	})

	t.Run("Unauthorized Call", func(t *testing.T) {
		tUrl, err := url.Parse("testURL")
		require.NoError(t, err)

		aChecker := newMockAuthorizationChecker(t)
		uServer := newMockUnauthorizedServer(t)

		fwdMock := &mocks.Handler{}

		aChecker.EXPECT().IsAuthorized(mock.Anything).Return(false)
		uServer.EXPECT().ServeUnauthorized(mock.Anything, mock.Anything)

		ph := proxyHandler{
			targetURL:            tUrl,
			forwarder:            fwdMock,
			unauthorizedServer:   uServer,
			authorizationChecker: aChecker,
		}

		req, err := http.NewRequest(http.MethodGet, "otherURL", nil)
		require.NoError(t, err)

		ph.ServeHTTP(httptest.NewRecorder(), req)

		fwdMock.AssertNotCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
		fwdMock.AssertExpectations(t)
	})
}

package proxy

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/mocks"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

func TestCreateProxyHandler(t *testing.T) {
	t.Run("create handler", func(t *testing.T) {
		targetURL := "testURL"

		handler, err := createProxyHandler(targetURL, authorizationHeaders{}, &cas.Client{}, "", "")

		assert.NoError(t, err)
		assert.NotNil(t, handler)
	})

	t.Run("invalid url", func(t *testing.T) {

		invalidTargetURL := ":example.com"

		_, err := createProxyHandler(invalidTargetURL, authorizationHeaders{}, nil, "", "")

		assert.Error(t, err)
	})
}

func TestProxyHandler_ServeHTTP(t *testing.T) {
	t.Run("ServeHTTP", func(t *testing.T) {
		tUrl, err := url.Parse("otherURL")
		require.NoError(t, err)

		fwdMock := &mocks.Handler{
			MserveHTTP: func(w http.ResponseWriter, r *http.Request) {
				assert.Equal(t, tUrl, r.URL)
			},
		}

		fwdMock.On("ServeHTTP", mock.Anything, mock.Anything)

		ph := proxyHandler{
			targetURL:        tUrl,
			forwarder:        fwdMock,
			casAuthenticated: func(r *http.Request) bool { return true },
		}

		req, err := http.NewRequest(http.MethodGet, "otherURL", nil)
		require.NoError(t, err)

		ph.ServeHTTP(httptest.NewRecorder(), req)

		fwdMock.AssertCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
		fwdMock.AssertExpectations(t)
	})

	t.Run("front channel logout", func(t *testing.T) {
		tUrl, err := url.Parse("testURL")
		require.NoError(t, err)

		fwdMock := &mocks.Handler{}

		ph := proxyHandler{
			targetURL:             tUrl,
			forwarder:             fwdMock,
			logoutPath:            "/sonar/sessions/logout",
			logoutRedirectionPath: "/sonar/",
		}

		req, err := http.NewRequest(http.MethodGet, "/sonar/", nil)
		req.Header.Add("Referer", "10.20.30.40/sonar/sessions/logout")
		require.NoError(t, err)

		ph.ServeHTTP(httptest.NewRecorder(), req)

		fwdMock.AssertNotCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
		fwdMock.AssertExpectations(t)
	})
	t.Run("Unauthenticated Call", func(t *testing.T) {
		tUrl, err := url.Parse("testURL")
		require.NoError(t, err)

		fwdMock := &mocks.Handler{}

		ph := proxyHandler{
			targetURL:        tUrl,
			forwarder:        fwdMock,
			casAuthenticated: func(r *http.Request) bool { return false },
		}

		req, err := http.NewRequest(http.MethodGet, "otherURL", nil)
		require.NoError(t, err)

		ph.ServeHTTP(httptest.NewRecorder(), req)

		fwdMock.AssertNotCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
		fwdMock.AssertExpectations(t)
	})
}

package proxy

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/cloudogu/sonar/sonarcarp/logging"
	"github.com/cloudogu/sonar/sonarcarp/throttling"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/cloudogu/go-cas"

	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/cloudogu/sonar/sonarcarp/mocks"
)

func TestCreateProxyHandler(t *testing.T) {
	t.Run("create handler", func(t *testing.T) {
		targetURL := "testURL"
		testCfg := config.Configuration{ServiceUrl: targetURL}

		handler, err := createProxyHandler(authorizationHeaders{}, &cas.Client{}, testCfg)

		assert.NoError(t, err)
		assert.NotNil(t, handler)
	})

	t.Run("invalid url", func(t *testing.T) {
		invalidTargetURL := ":example.com"
		testCfg := config.Configuration{ServiceUrl: invalidTargetURL}

		_, err := createProxyHandler(authorizationHeaders{}, nil, testCfg)

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
	t.Run("try double writeheader for backchannel logout cas request", func(t *testing.T) {
		tUrl, err := url.Parse("http://localhost:9000/sonar/")
		require.NoError(t, err)

		fwdMock := &mocks.Handler{
			MserveHTTP: func(w http.ResponseWriter, r *http.Request) {
				assert.Equal(t, tUrl, r.URL)
				w.WriteHeader(http.StatusFound)
				_, lerr := w.Write([]byte("Location: https://192.168.56.2/cas/logout"))
				require.NoError(t, lerr)
			},
		}

		fwdMock.On("ServeHTTP", mock.Anything, mock.Anything).Return()

		ph := proxyHandler{
			targetURL:        tUrl,
			forwarder:        fwdMock,
			casAuthenticated: func(r *http.Request) bool { return true },
		}
		testctx := context.Background()
		cfg := config.Configuration{}
		sut := logging.Middleware(throttling.NewThrottlingHandler(testctx, cfg, ph), "testThrottlingHandler")

		req, err := http.NewRequest(http.MethodPost, "http://localhost:8080/sonar/", nil)
		req.Header.Add("Location", "https://192.168.56.2/cas/logout")
		req.Header.Add("Set-Cookie", "_cas-session=102938471023984710239874")
		require.NoError(t, err)

		sut.ServeHTTP(httptest.NewRecorder(), req)

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
	t.Run("Unauthenticated browser request does not call forwarder", func(t *testing.T) {
		tUrl, err := url.Parse("/sonar/api/testURL")
		require.NoError(t, err)

		fwdMock := &mocks.Handler{}

		ph := proxyHandler{
			targetURL:        tUrl,
			forwarder:        fwdMock,
			casAuthenticated: func(r *http.Request) bool { return false },
		}

		req, err := http.NewRequest(http.MethodGet, "/sonar/api/otherURL", nil)
		require.NoError(t, err)
		req.Header.Add("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0")

		// when
		ph.ServeHTTP(httptest.NewRecorder(), req)

		// then
		fwdMock.AssertNotCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
		fwdMock.AssertExpectations(t)
	})
	t.Run("Unauthenticated other request goes through failing forwarder", func(t *testing.T) {
		// given
		tUrl, err := url.Parse("/sonar/api/testURL")
		require.NoError(t, err)

		fwdMock := &mocks.Handler{}
		fwdMock.On("ServeHTTP", mock.Anything, mock.Anything).Run(func(args mock.Arguments) {
			// then
			writerRaw := args.Get(0)
			writer := writerRaw.(http.ResponseWriter)
			writer.WriteHeader(http.StatusUnauthorized)
			_, _ = writer.Write([]byte("you nasty hacker!"))
		})

		ph := proxyHandler{
			targetURL:        tUrl,
			forwarder:        fwdMock,
			casAuthenticated: func(r *http.Request) bool { return false },
		}

		req, err := http.NewRequest(http.MethodGet, "/sonar/api/otherURL", nil)
		require.NoError(t, err)
		req.Header.Add("User-Agent", "curl/1.2.3")

		recorder := httptest.NewRecorder()
		// when
		ph.ServeHTTP(recorder, req)

		// then
		assert.Equal(t, http.StatusUnauthorized, recorder.Code)
		fwdMock.AssertCalled(t, "ServeHTTP", mock.Anything, mock.Anything)
		fwdMock.AssertExpectations(t)
	})
}

func Test_isInAdminGroup(t *testing.T) {
	cesAdminGroup := "cesPowerAdmin3000™"
	type args struct {
		currentGroups []string
	}
	tests := []struct {
		name string
		args args
		want bool
	}{
		{"no groups imply regular user permissions", args{[]string{}}, false},
		{"one regular group imply regular user permissions", args{[]string{"hello"}}, false},
		{"one regular group imply regular user permissions", args{[]string{"bon jour", "groupe-normale"}}, false},
		{"multiple regular groups imply regular user permissions", args{[]string{"ohaiyogozaimasu", "permission-san", cesAdminGroup}}, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, isInAdminGroup(tt.args.currentGroups, cesAdminGroup), "isInAdminGroup(%v, %v)", tt.args.currentGroups, cesAdminGroup)
		})
	}
}

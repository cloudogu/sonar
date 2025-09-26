package proxy

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/cloudogu/sonar/sonarcarp/config"
)

const (
	testAppContextPath = "/sonar"
)

var testHeaders = AuthorizationHeaders{
	Principal: "X-Forwarded-Login",
	Role:      "X-Forwarded-Groups",
	Mail:      "X-Forwarded-Email",
	Name:      "X-Forwarded-Name",
}

func TestCreateProxyHandler(t *testing.T) {
	t.Run("create handler", func(t *testing.T) {
		targetURL := "testURL"
		testCfg := config.Configuration{ServiceUrl: targetURL}

		handler, err := CreateProxyHandler(AuthorizationHeaders{}, testCfg)

		assert.NoError(t, err)
		assert.NotNil(t, handler)
		assert.Implements(t, (*http.Handler)(nil), handler)
	})

	t.Run("invalid url", func(t *testing.T) {
		invalidTargetURL := ":example.com"
		testCfg := config.Configuration{ServiceUrl: invalidTargetURL}

		_, err := CreateProxyHandler(AuthorizationHeaders{}, testCfg)

		assert.Error(t, err)
	})
}

func TestProxyHandler_ServeHTTP(t *testing.T) {
	cfg := config.Configuration{
		AppContextPath:                 testAppContextPath,
		LogoutPathFrontchannelEndpoint: "/sessions/logout",
		LogoutPathBackchannelEndpoint:  "/api/authentication/logout",
	}

	t.Run("add auth headers to authenticated requests", func(t *testing.T) {
		sonarMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			assert.Equal(t, testAppContextPath+"/projects/create", r.URL.Path)
		}))
		defer sonarMock.Close()
		cfg.ServiceUrl = sonarMock.URL

		sut, err := CreateProxyHandler(testHeaders, cfg)
		require.NoError(t, err)
		carpServer := httptest.NewServer(sut)
		defer carpServer.Close()
		targetUrl := carpServer.URL + testAppContextPath + "/projects/create"

		req, err := http.NewRequest(http.MethodGet, targetUrl, nil)

		actualResp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		assert.Equal(t, http.StatusOK, actualResp.StatusCode)
	})
	t.Run("front channel logout", func(t *testing.T) {
		sonarMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusFound)
			w.Header().Add("Location", "/sonar/")
		}))
		defer sonarMock.Close()
		cfg.ServiceUrl = sonarMock.URL

		casClientMock := newMockCasClient(t)
		casClientMock.EXPECT().RedirectToLogout(mock.Anything, mock.Anything).Run(func(w http.ResponseWriter, r *http.Request) {
			log.Debugf("redirect to logout")
			w.WriteHeader(http.StatusOK)
			assert.Equal(t, "/sonar/api/authentication/logout", r.URL.Path)
		})

		sut, err := CreateProxyHandler(testHeaders, cfg)
		require.NoError(t, err)
		sut.casClient = casClientMock
		carpServer := httptest.NewServer(sut)
		defer carpServer.Close()

		// clicking on SonarQube's logout button leads first to a GET /sonar/sessions/logout request which will be redirected
		// to a GET /sonar/api/authentication/logout request
		req, err := http.NewRequest(http.MethodGet, carpServer.URL+testAppContextPath+cfg.LogoutPathBackchannelEndpoint, nil)
		req.Header.Add("Referer", carpServer.URL+testAppContextPath+cfg.LogoutPathFrontchannelEndpoint)

		// when
		actualResp, err := http.DefaultClient.Do(req)

		// then
		require.NoError(t, err)
		assert.Equal(t, http.StatusOK, actualResp.StatusCode)
	})
	t.Run("proxy non-auth resource requests as-is", func(t *testing.T) {
		sonarMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			assert.Equal(t, "/sonar/js/lefile.js", r.URL.Path)
		}))
		defer sonarMock.Close()
		cfg.ServiceUrl = sonarMock.URL

		casClientMock := newMockCasClient(t)

		sut, err := CreateProxyHandler(testHeaders, cfg)
		require.NoError(t, err)
		sut.casClient = casClientMock
		carpServer := httptest.NewServer(sut)
		defer carpServer.Close()

		req, err := http.NewRequest(http.MethodGet, carpServer.URL+testAppContextPath+"/js/lefile.js", nil)

		// when
		actualResp, err := http.DefaultClient.Do(req)

		// then
		require.NoError(t, err)
		assert.Equal(t, http.StatusOK, actualResp.StatusCode)
	})
	t.Run("Unauthenticated browser request does not call forwarder", func(t *testing.T) {
		sonarMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			t.Fatalf("unexpected sonar call to %s", r.URL.Path)
		}))
		defer sonarMock.Close()
		cfg.ServiceUrl = sonarMock.URL

		casClientMock := newMockCasClient(t)
		casClientMock.EXPECT().IsAuthenticated(mock.Anything).Return(false)
		casClientMock.EXPECT().RedirectToLogout(mock.Anything, mock.Anything).Return()

		sut, err := CreateProxyHandler(testHeaders, cfg)
		require.NoError(t, err)
		sut.casClient = casClientMock
		carpServer := httptest.NewServer(sut)
		defer carpServer.Close()

		req, err := http.NewRequest(http.MethodGet, carpServer.URL+testAppContextPath+"/anything", nil)
		req.Header.Add("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0")

		// when
		actualResp, err := http.DefaultClient.Do(req)

		// then
		require.NoError(t, err)
		assert.Equal(t, http.StatusOK, actualResp.StatusCode)

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

package proxy

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cloudogu/go-cas/v2"
	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/cloudogu/sonar/sonarcarp/config"
)

const (
	testAppContextPath = "/sonar"
	browserUserAgent   = "Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0"
)

const (
	testUsername = "john.q.public"
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
		CarpResourcePaths:              []string{"/sonar/js/"},
	}

	err := internal.InitStaticResourceMatchers(cfg.CarpResourcePaths)
	require.NoError(t, err)
	defer internal.InitStaticResourceMatchers([]string{})

	t.Run("proxy passes-thru requests to resources marked as non-auth-worthy", func(t *testing.T) {
		sonarMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			assert.Equal(t, testAppContextPath+"/js/lefile.js", r.URL.Path)
		}))
		defer sonarMock.Close()
		cfg.ServiceUrl = sonarMock.URL

		sut, err := CreateProxyHandler(testHeaders, cfg)
		require.NoError(t, err)
		carpServer := httptest.NewServer(sut)
		defer carpServer.Close()
		targetUrl := carpServer.URL + testAppContextPath + "/js/lefile.js"

		req, err := http.NewRequest(http.MethodGet, targetUrl, nil)
		req.Header.Set("User-Agent", browserUserAgent)

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
		casClientMock.EXPECT().RedirectToLogin(mock.Anything, mock.Anything).Return()

		sut, err := CreateProxyHandler(testHeaders, cfg)
		require.NoError(t, err)
		sut.casClient = casClientMock
		carpServer := httptest.NewServer(sut)
		defer carpServer.Close()

		req, err := http.NewRequest(http.MethodGet, carpServer.URL+testAppContextPath+"/anything", nil)
		req.Header.Add("User-Agent", browserUserAgent)

		// when
		actualResp, err := http.DefaultClient.Do(req)

		// then
		require.NoError(t, err)
		assert.Equal(t, http.StatusOK, actualResp.StatusCode)

	})
	t.Run("Unauthenticated api request should return code 401", func(t *testing.T) {
		sonarMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			t.Fatalf("unexpected sonar call to %s", r.URL.Path)
		}))
		defer sonarMock.Close()
		cfg.ServiceUrl = sonarMock.URL

		casClientMock := newMockCasClient(t)
		casClientMock.EXPECT().IsAuthenticated(mock.Anything).Return(false)

		sut, err := CreateProxyHandler(testHeaders, cfg)
		require.NoError(t, err)
		sut.casClient = casClientMock
		carpServer := httptest.NewServer(sut)
		defer carpServer.Close()

		req, err := http.NewRequest(http.MethodGet, carpServer.URL+testAppContextPath+"/api/test", nil)
		req.Header.Add("User-Agent", browserUserAgent)

		// when
		actualResp, err := http.DefaultClient.Do(req)

		// then
		require.NoError(t, err)
		assert.Equal(t, http.StatusUnauthorized, actualResp.StatusCode)

	})
	t.Run("request to sessions that are no logout should be redirected to appContextPath", func(t *testing.T) {
		sonarMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			t.Fatalf("unexpected sonar call to %s", r.URL.Path)
		}))
		defer sonarMock.Close()
		cfg.ServiceUrl = sonarMock.URL

		casClientMock := newMockCasClient(t)

		sut, err := CreateProxyHandler(testHeaders, cfg)
		require.NoError(t, err)
		sut.casClient = casClientMock
		carpServer := httptest.NewServer(sut)
		defer carpServer.Close()

		req, err := http.NewRequest(http.MethodGet, carpServer.URL+testAppContextPath+"/sessions/new", nil)
		req.Header.Add("User-Agent", browserUserAgent)

		client := &http.Client{
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				return http.ErrUseLastResponse
			},
		}

		// when
		actualResp, err := client.Do(req)

		// then
		require.NoError(t, err)
		assert.Equal(t, http.StatusFound, actualResp.StatusCode)
		assert.Equal(t, testAppContextPath, actualResp.Header.Get("Location"))

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

func Test_proxyHandler_getCasAttributes(t *testing.T) {
	t.Run("should return attributes", func(t *testing.T) {
		// given
		testReq := &http.Request{}

		casClientMock := newMockCasClient(t)
		casClientMock.EXPECT().Username(testReq).Return(testUsername)
		mockedAttrs := cas.UserAttributes{}
		// the actual keys are subject to configuration
		mockedAttrs.Add("1-name", "John Q Public")
		mockedAttrs.Add("2-mail", "jqp@example.invalid")
		mockedAttrs.Add("3-groups", "super-sonar-users")
		casClientMock.EXPECT().Attributes(testReq).Return(mockedAttrs)

		sut := proxyHandler{casClient: casClientMock}

		// when
		actualUser, actualAttrs := sut.getCasAttributes(testReq)

		// then
		assert.Equal(t, testUsername, actualUser)
		assert.Equal(t, "John Q Public", actualAttrs.Get("1-name"))
		assert.Equal(t, "jqp@example.invalid", actualAttrs.Get("2-mail"))
		assert.Equal(t, "super-sonar-users", actualAttrs.Get("3-groups"))
	})
}

func Test_setHeaders(t *testing.T) {
	testAdminGroupMapping := sonarAdminGroupMapping{
		cesAdminGroup:   "ces-super-admin-3000",
		sonarAdminGroup: "sonar-administrators",
	}

	t.Run("should set regular headers", func(t *testing.T) {
		// given
		sut, err := http.NewRequest(http.MethodGet, "https://example.invalid/", nil)
		require.NoError(t, err)

		testCasAttrs := cas.UserAttributes{}
		testCasAttrs.Add("displayName", "John Q Public")
		testCasAttrs.Add("mail", "jqp@example.invalid")
		testCasAttrs.Add("groups", "super-duper-sonar-users,common-ces-user")

		// when
		setHeaders(sut, testUsername, testCasAttrs, testHeaders, testAdminGroupMapping)

		// then
		require.Len(t, sut.Header, 4)
		assert.Equal(t, "john.q.public", sut.Header.Get(testHeaders.Principal))
		assert.Equal(t, "John Q Public", sut.Header.Get(testHeaders.Name))
		assert.Equal(t, "jqp@example.invalid", sut.Header.Get(testHeaders.Mail))
		assert.Equal(t, "super-duper-sonar-users,common-ces-user", sut.Header.Get(testHeaders.Role))
	})
	t.Run("should add sonar admin group to CES admin user", func(t *testing.T) {
		// given
		sut, err := http.NewRequest(http.MethodGet, "https://example.invalid/", nil)
		require.NoError(t, err)

		testCasAttrs := cas.UserAttributes{}
		testCasAttrs.Add("displayName", "John Q Public")
		testCasAttrs.Add("mail", "jqp@example.invalid")
		testCasAttrs.Add("groups", "super-duper-sonar-users,common-ces-user,ces-super-admin-3000")

		// when
		setHeaders(sut, testUsername, testCasAttrs, testHeaders, testAdminGroupMapping)

		// then
		require.Len(t, sut.Header, 4)
		assert.Equal(t, "john.q.public", sut.Header.Get(testHeaders.Principal))
		assert.Equal(t, "John Q Public", sut.Header.Get(testHeaders.Name))
		assert.Equal(t, "jqp@example.invalid", sut.Header.Get(testHeaders.Mail))
		assert.Equal(t, "super-duper-sonar-users,common-ces-user,ces-super-admin-3000,sonar-administrators", sut.Header.Get(testHeaders.Role))
	})
}

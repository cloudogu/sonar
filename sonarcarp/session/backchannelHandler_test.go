package session

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

const testSamlLogoutMessage = `<samlp:LogoutRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" ID="LR-18-0Gq9gtdqUocxj5jbhhafkHQE" Version="2.0" IssueInstant="2025-09-18T11:33:41Z"><saml:NameID xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">john.q.public</saml:NameID><samlp:SessionIndex>ST-18-HdnrDDK-phvPpNCb5sxucU2cLEg-cas</samlp:SessionIndex></samlp:LogoutRequest>`
const testUsername = "john.q.public"

func Test_getUserFromSamlLogout(t *testing.T) {
	tests := []struct {
		name              string
		urldecodedSamlMsg string
		want              string
		wantErr           assert.ErrorAssertionFunc
	}{
		{"return john.q.public", testSamlLogoutMessage, testUsername, assert.NoError},
		{"return EOF error", "", "", assert.Error},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := getUserFromSamlLogout(tt.urldecodedSamlMsg)
			if !tt.wantErr(t, err, fmt.Sprintf("getUserFromSamlLogout(%v)", tt.urldecodedSamlMsg)) {
				return
			}
			assert.Equalf(t, tt.want, got, "getUserFromSamlLogout(%v)", tt.urldecodedSamlMsg)
		})
	}
}

var testCtx = context.Background()

func TestThrottlingHandler(t *testing.T) {
	testCfg := config.Configuration{
		AppContextPath: "/sonar",
	}

	t.Run("pass-thru regular requests", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusOK)
		}
		casClientMock := newMockCasClient(t)

		sut := Middleware(handler, testCfg, casClientMock)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			sut.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer server.Close()

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		require.NoError(t, err)

		// when
		resp, lErr := server.Client().Do(req)

		// then
		assert.NoError(t, lErr)
		assert.Equal(t, http.StatusOK, resp.StatusCode)
		assert.Empty(t, resp.Header.Get("Location"))
	})

	t.Run("logout in sonar server mock and CAS server mocks", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusTeapot)
		}

		sonarWasCalled := false
		sonarMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			sonarWasCalled = true
		}))
		defer sonarMock.Close()
		testCfg.ServiceUrl = sonarMock.URL
		defer func() { testCfg.ServiceUrl = "" }()

		casWasCalled := false
		casMock := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusTeapot)
			casWasCalled = true
		}))
		defer casMock.Close()
		testCfg.CasUrl = casMock.URL
		defer func() { testCfg.ServiceUrl = "" }()

		casClientMock := newMockCasClient(t)
		casClientMock.EXPECT().Logout(mock.Anything, mock.Anything).Run(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Location", testCfg.CasUrl)
			w.WriteHeader(http.StatusFound)
		})
		// these will be retrieved on bc logout
		upsertUser(testUsername, "leJwt", "leXsrf")
		defer cleanJwtUserSessions()

		sut := Middleware(handler, testCfg, casClientMock)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			sut.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer server.Close()

		req, err := http.NewRequest(http.MethodPost, server.URL+"/sonar/", strings.NewReader(fmt.Sprintf("logoutRequest=%s", testSamlLogoutMessage)))
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded") // imply that POST form values are set to be parsed

		require.NoError(t, err)

		// when
		resp, lErr := server.Client().Do(req)

		// then
		assert.NoError(t, lErr)
		casWasHitByHttpClient := http.StatusTeapot
		assert.Equal(t, casWasHitByHttpClient, resp.StatusCode)
		assert.True(t, casWasCalled)
		assert.True(t, sonarWasCalled)
		// memory management was done for this user
		assert.Empty(t, jwtUserSessions)
	})
}

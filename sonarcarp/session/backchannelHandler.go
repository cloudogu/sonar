package session

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"net/url"

	"github.com/cloudogu/sonar/sonarcarp/config"
)

// set out for mocking purposes
var httpClient = &http.Client{}

// Middleware creates a delegate ResponseWriter that catches backchannel logout requests and creates a side request to
// logout in SonarQube.
func Middleware(next http.Handler, configuration config.Configuration) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		log.Debugf("backchannelHandler was called for %s", request.URL.String())

		if !isBackChannelLogoutRequest(request) {
			log.Debug("Request is not a backchannel logout, proceed in filter chain")
			next.ServeHTTP(writer, request)
			return
		}

		casUser, err := getUserFromCasLogout(request)
		if err != nil {
			log.Errorf("Failed to get user from CAS logout request: %s", err.Error())
			next.ServeHTTP(writer, request)
			return
		}

		user := GetUserByUsername(casUser)
		if user.isNullUser() {
			log.Warningf("Skipping sonarqube logout for user %s", casUser)
			next.ServeHTTP(writer, request)
			return
		}

		if err := doFrontChannelLogout(configuration, user, casUser); err != nil {
			log.Errorf("Failed to logout user %s against sonarqube: %s", casUser, err.Error())
			next.ServeHTTP(writer, request)
			return
		}

		log.Debugf("Calling sonar logout for user %s", casUser)
		next.ServeHTTP(writer, request)
		return
	})
}

func doFrontChannelLogout(configuration config.Configuration, user User, casUser string) error {
	sonarLogoutReq, err := buildLogoutRequest(configuration, user)
	if err != nil {
		return fmt.Errorf("failed to build logout request while logging out user %s: %w", casUser, err)
	}

	logoutResp, err := httpClient.Do(sonarLogoutReq)
	if err != nil {
		return fmt.Errorf("failed to send logout request while logging out user %s: %w", casUser, err)
	}

	if logoutResp.StatusCode > 300 {
		var respBody []byte
		if logoutResp.Body != nil {
			respBody, err = io.ReadAll(logoutResp.Body)
			if err != nil {
				return fmt.Errorf("failed to read logout response body while logging out user %s: %w", casUser, err)
			}

		}
		return fmt.Errorf("failed to logout user %s after CAS backchannel logout: Response HTTP %d: %s", casUser, logoutResp.StatusCode, string(respBody))
	}

	return nil
}

func buildLogoutRequest(configuration config.Configuration, user User) (*http.Request, error) {
	sonarBaseUrl := configuration.ServiceUrl
	sonarLogoutUrl := configuration.LogoutPath
	fullLogoutUrl, err := url.JoinPath(sonarBaseUrl, sonarLogoutUrl)
	if err != nil {
		return nil, fmt.Errorf("failed to join sonarqube logout request from %s and %s: %w", sonarBaseUrl, sonarLogoutUrl, err)
	}

	sonarLogoutReq, err := http.NewRequest(http.MethodPost, fullLogoutUrl, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create sonarqube logout request: %w", err)
	}

	sessionCookie := &http.Cookie{
		Name:   cookieNameJwtSession,
		Value:  user.JwtToken,
		Path:   "/sonar",
		MaxAge: 60,
	}

	sonarLogoutReq.AddCookie(sessionCookie)

	return sonarLogoutReq, nil
}

func getUserFromCasLogout(r *http.Request) (string, error) {
	if r.Body == nil {
		return "", fmt.Errorf("failed to get body from CAS backchannel logout request to %s %s ", r.Method, r.URL.String())
	}

	all, err := io.ReadAll(r.Body)
	if err != nil {
		return "", fmt.Errorf("read error occurred on CAS backchannel logout request body: %w", err)
	}
	samlLogoutMessage, err := url.QueryUnescape(string(all))
	if err != nil {
		return "", fmt.Errorf("error while unescaping CAS backchannel logout request message '%s: %w", all, err)
	}

	casUser := getUserFromSamlLogout(samlLogoutMessage)

	// put a non-read body back to the request and avoid a lot of potential request precessing problems
	r.Body = io.NopCloser(bytes.NewBuffer(all))

	return casUser, nil
}

func getUserFromSamlLogout(samlMsg string) string {
	return ""
}

func isBackChannelLogoutRequest(r *http.Request) bool {
	return r.Method == "POST" && (r.URL.Path == "/sonar/" || r.URL.Path == "/sonar")
}

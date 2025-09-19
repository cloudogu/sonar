package session

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"net/url"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/config"
)

// set out for mocking purposes
var httpClient = &http.Client{}

// Middleware creates a delegate ResponseWriter that catches backchannel logout requests and creates a side request to
// logout in SonarQube.
func Middleware(next http.Handler, configuration config.Configuration, casClient *cas.Client) http.Handler {
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

		user := getUserByUsername(casUser)
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
		casClient.Logout(writer, request)
		return
	})
}

func doFrontChannelLogout(configuration config.Configuration, user User, casUser string) error {
	sonarLogoutReq, err := buildLogoutRequest(configuration, user)
	if err != nil {
		return fmt.Errorf("failed to build logout request while logging out user %s: %w", casUser, err)
	}

	log.Debugf("Calling sonar logout request %s for user %s", sonarLogoutReq.URL.String(), casUser)
	logoutResp, err := httpClient.Do(sonarLogoutReq)
	if err != nil {
		return fmt.Errorf("failed to send logout request while logging out user %s: %w", casUser, err)
	}

	_, ok := jwtUserSessions[user.UserName]
	if ok {
		upsertUser(user.UserName, user.JwtToken, user.XsrfToken, true)
	}

	log.Debugf("Sonar logout response is %d", logoutResp.StatusCode)
	if logoutResp.StatusCode > 300 {
		var respBody []byte
		if logoutResp.Body != nil {
			respBody, err = io.ReadAll(logoutResp.Body)
			if err != nil {
				return fmt.Errorf("failed to read logout response body while logging out user %s: %w", casUser, err)
			}
		}

		logoutResp.Body = io.NopCloser(bytes.NewReader(respBody))
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

	//FIXME ffs dont commit this!!! it might work tho (L_L')
	fullLogoutUrl = "http://localhost:9000/sonar/api/authentication/logout"

	sonarLogoutReq, err := http.NewRequest(http.MethodPost, fullLogoutUrl, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create sonarqube logout request: %w", err)
	}

	//sonarLogoutReq.Header.Add("X-Forwarded-Proto", "https")
	sonarLogoutReq.Header.Add("X-XSRF-TOKEN", user.XsrfToken)
	sonarLogoutReq.Header.Add("Referer", "https://192.168.56.2/sonar/sessions/logout")
	sonarLogoutReq.Header.Add("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0")

	sessionCookie := &http.Cookie{
		Name:     cookieNameJwtSession,
		Value:    user.JwtToken,
		HttpOnly: true,
		Secure:   true,
		Path:     "/sonar",
	}
	xsrfCookie := &http.Cookie{
		Name:     "XSRF-TOKEN",
		Value:    user.XsrfToken,
		HttpOnly: false,
		Secure:   true,
		Path:     "/sonar",
	}

	log.Debugf("------------------- ..... using jwt cookie %s", user.JwtToken)
	log.Debugf("------------------- ..... using xsrf cookie %s", user.XsrfToken)
	sonarLogoutReq.AddCookie(sessionCookie)
	sonarLogoutReq.AddCookie(xsrfCookie)

	return sonarLogoutReq, nil
}

func getUserFromCasLogout(r *http.Request) (string, error) {
	err := r.ParseForm()
	if err != nil {
		return "", fmt.Errorf("CAS user logout lead to an error during parsing: %w", err)
	}
	log.Errorf("logout request query params: %s", r.PostForm)

	if r.Body == nil {
		log.Warning("Request body is nil for CAS logout request")
		return "", fmt.Errorf("failed to get body from CAS backchannel logout request to %s %s ", r.Method, r.URL.String())
	}

	samlLogoutMessage := r.PostForm.Get("logoutRequest") // as sent by the CAS request
	casUser, err := getUserFromSamlLogout(samlLogoutMessage)

	// put a non-read body back to the request and avoid a lot of potential request precessing problems
	r.Body = io.NopCloser(bytes.NewBuffer([]byte("logoutRequest=" + samlLogoutMessage))) // TODO CHECK if error

	return casUser, nil
}

func getUserFromSamlLogout(urldecodedSamlMsg string) (string, error) {
	samlParsed := new(logoutSamlRequestMessage)
	err := xml.Unmarshal([]byte(urldecodedSamlMsg), &samlParsed)
	if err != nil {
		return "", fmt.Errorf("failed to parse SAML logout request %s: %w", urldecodedSamlMsg, err)
	}

	return samlParsed.NameID, nil
}

func isBackChannelLogoutRequest(r *http.Request) bool {
	return r.Method == "POST" && (r.URL.Path == "/sonar/" || r.URL.Path == "/sonar")
}

type logoutSamlRequestMessage struct {
	XMLName      xml.Name `xml:"LogoutRequest"`
	NameID       string   `xml:"NameID"`
	SessionIndex string   `xml:"SessionIndex"`
}

func getCasAttributes(r *http.Request) (string, cas.UserAttributes) {
	username := cas.Username(r)
	attrs := cas.Attributes(r)
	return username, attrs
}

package proxy

import (
	"net/http"

	"github.com/cloudogu/go-cas"
)

// AuthorizationHeaders contain the mapping from config value to HTTP header name for SonarQube HTTP proxy authentication.
type AuthorizationHeaders struct {
	// Principal contains the user ID header name.
	Principal string
	// Role contains the user group header name.
	//
	// Even without group, SonarQube will assign the group "sonar-users" internally.
	Role string
	// Mail contains the user mail header name.
	Mail string
	// Name contains the user display name header name.
	Name string
}

type sonarAdminGroupMapping struct {
	cesAdminGroup   string
	sonarAdminGroup string
}

// casClient extracts static go-cas functions into testable functions.
type casClient interface {
	// RedirectToLogin handles unauthenticated users so the browser shows the CAS login page.
	RedirectToLogin(w http.ResponseWriter, r *http.Request)
	// RedirectToLogout allows CAS protected handlers to redirect a request to the CAS logout page.
	RedirectToLogout(w http.ResponseWriter, r *http.Request)
	// Username returns a CAS username to a CAS session cookie from the given request.
	Username(r *http.Request) string
	// Attributes returns other CAS user attributes to a CAS session cookie from the given request.
	Attributes(r *http.Request) cas.UserAttributes
	// IsAuthenticated returns whether a request indicates if the request's user is CAS authenticated.
	IsAuthenticated(*http.Request) bool
}

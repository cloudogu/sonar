package session

import (
	"net/http"
)

const cookieNameJwtSession = "JWT-SESSION"

func SaveJwtTokensFor(casUsername string, cookies []*http.Cookie) {
	jwtCookie := ""
	xsrfCookie := ""

	for _, cookie := range cookies {
		if cookie.Name == cookieNameJwtSession {
			log.Debugf("==== Hey I found a JWT: value: %s path %s ; dom %s ; exp %s", cookie.Value, cookie.Path, cookie.Domain, cookie.Expires)
			jwtCookie = cookie.Value
			continue
		}

		if cookie.Name == "XSRF-TOKEN" {
			log.Debugf("==== Hey I found a xsrf: value: %s path %s ; dom %s ; exp %s", cookie.Value, cookie.Path, cookie.Domain, cookie.Expires)
			xsrfCookie = cookie.Value
			continue
		}

	}

	if jwtCookie == "" || xsrfCookie == "" {
		log.Infof("No sonarqube session cookie found for %s", casUsername)
		return
	}

	// we do not check the cookie's path here because the sonar cookie is not set in the path attribute
	log.Debugf("Found JWT session cookie for user %s, adding to session map", casUsername)
	upsertUser(casUsername, jwtCookie, xsrfCookie, false)
}

func getUserByUsername(casUsername string) User {
	mu.Lock()
	defer mu.Unlock()
	log.Errorf("##### current jwt session map %+v", jwtUserSessions)
	user, ok := jwtUserSessions[casUsername]
	if !ok {
		log.Warningf("Could not find CAS user %s for session invalidation", casUsername)
		return nullUser
	}

	return user
}

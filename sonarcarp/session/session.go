package session

import (
	"net/http"
)

const cookieNameJwtSession = "JWT-SESSION"

func SaveJwtTokensFor(casUsername string, cookies []*http.Cookie) {
	sessionCookieFound := false
	for _, cookie := range cookies {
		if cookie.Name != cookieNameJwtSession {
			continue
		}

		// we do not check the cookie's path here because the sonar cookie is not set in the path attribute
		log.Debugf("Found JWT session cookie for user %s, adding to session map", casUsername)
		upsertUser(casUsername, cookie.Value, false)

		sessionCookieFound = true
	}

	if !sessionCookieFound {
		log.Infof("No sonarqube session cookie found for %s", casUsername)
	}
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

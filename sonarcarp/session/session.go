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

		if cookie.Path != "/sonar" { // TODO take configuration value instead
			continue
		}

		log.Debugf("Found JWT session cookie for user %s, adding to session map", casUsername)
		upsertUser(casUsername, cookie.Value)

		sessionCookieFound = true
	}

	if !sessionCookieFound {
		log.Infof("No sonarqube session cookie found for %s", casUsername)
	}
}

func GetUserByUsername(casUsername string) User {
	mu.Lock()
	defer mu.Unlock()

	user, ok := jwtUserSessions[casUsername]
	if !ok {
		log.Warningf("Could not find CAS user %s for session invalidation", casUsername)
		return nullUser
	}

	return user
}

func IsNullUser(user User) bool {
	return user == nullUser
}

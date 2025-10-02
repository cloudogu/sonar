package session

import (
	"context"
	"sync"
	"time"
)

const (
	// JwtSessionCleanInterval contains the default time window in seconds between all JWT tokens will be checked if
	// they can be removed.
	JwtSessionCleanInterval = 86400
)

var (
	mu              sync.RWMutex
	jwtUserSessions = make(map[string]User)
)

// InitCleanJob starts the background job responsible for cleaning up invalid sonarqube session JWT tokens.
func InitCleanJob(ctx context.Context, cleanInterval int) {
	if cleanInterval == 0 {
		cleanInterval = JwtSessionCleanInterval
	}
	go startCleanJob(ctx, cleanInterval)
}

var nullUser = User{}

func cleanUser(username string) {
	mu.Lock()
	defer mu.Unlock()

	log.Debugf("Resetting limiter for %s", username)
	delete(jwtUserSessions, username)
}

func upsertUser(username, jwtToken, xsrfToken string) {
	mu.Lock()
	defer mu.Unlock()

	jwtUserSessions[username] = User{UserName: username, JwtToken: jwtToken, XsrfToken: xsrfToken}

	return
}

func cleanJwtUserSessions() {
	mu.Lock()
	defer mu.Unlock()

	numberCleaned := 0
	for username, user := range jwtUserSessions {
		expirationDate, err := getTokenExpirationDate(user.JwtToken)
		if err != nil {
			log.Errorf("Could not get expiration date for user %s and token %s: %v", username, user.JwtToken, err)
			continue
		}
		if expirationDate.Before(time.Now()) {
			log.Debugf("Cleaning token for %s", user.UserName)
			delete(jwtUserSessions, username) // DO NOT refactor with cleanUser() because both try to acquire a lock
		}
		numberCleaned++
	}

	if numberCleaned > 0 {
		log.Infof("Removed limiters for %d jwtUserSessions", numberCleaned)
	}
}

func startCleanJob(ctx context.Context, cleanInterval int) {
	tick := time.Tick(time.Duration(cleanInterval) * time.Second)

	for {
		select {
		case <-ctx.Done():
			log.Info("Context done. Stop throttling cleanup job")
			return
		case <-tick:
			log.Info("Start cleanup for jwtUserSessions in throttling map")
			cleanJwtUserSessions()
		}
	}
}

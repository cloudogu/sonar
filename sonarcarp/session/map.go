package session

import (
	"context"
	"sync"
	"time"
)

const (
	// JwtSessionCleanInterval contains the default time window in seconds between all JWT tokens will be checked if
	// they can be removed.
	JwtSessionCleanInterval = 3000
)

var (
	mu              sync.RWMutex
	jwtUserSessions = make(map[string]User)
)

// InitCleanJob starts the background job responsible for cleaning up invalid sonarqube session JWT tokens.
func InitCleanJob(ctx context.Context, cleanInterval int) {
	go startCleanJob(ctx, cleanInterval)
}

var nullUser = User{}

func cleanClient(clientHandle string) {
	mu.Lock()
	defer mu.Unlock()

	log.Debugf("Resetting limiter for %s", clientHandle)
	delete(jwtUserSessions, clientHandle)
}

func upsertUser(username, jwtToken, xsrfToken string, invalid bool) {
	mu.Lock()
	defer mu.Unlock()

	jwtUserSessions[username] = User{UserName: username, JwtToken: jwtToken, XsrfToken: xsrfToken, Invalid: invalid}

	return
}

func cleanJwtUserSessions() {
	mu.Lock()
	defer mu.Unlock()

	numberCleaned := 0
	for jwtToken, user := range jwtUserSessions {
		expirationDate, err := getTokenExpirationDate(jwtToken)
		if err != nil {
			log.Errorf("Could not get expiration date for token %s: %v", jwtToken, err)
			continue
		}
		if time.Now().Before(expirationDate) {
			log.Debugf("Cleaning token for %s", user.UserName)
			delete(jwtUserSessions, jwtToken)
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

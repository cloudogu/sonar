package session

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/op/go-logging"
)

var (
	mu              sync.RWMutex
	jwtUserSessions = make(map[string]User)
	nullUser        = User{}
)

var log = logging.MustGetLogger("session")

const (
	// JwtSessionCleanInterval contains the default time window in seconds between all JWT tokens will be checked if
	// they can be removed.
	JwtSessionCleanInterval = 3000
)

// InitCleanJob starts the background job responsible for cleaning up invalid sonarqube session JWT tokens.
func InitCleanJob(ctx context.Context, cleanInterval int) {
	go startCleanJob(ctx, cleanInterval)
}

func GetUserByJwtToken(jwtToken string) User {
	mu.Lock()
	defer mu.Unlock()

	user, ok := jwtUserSessions[jwtToken]
	if !ok {
		return nullUser
	}

	return user
}

func cleanClient(clientHandle string) {
	mu.Lock()
	defer mu.Unlock()

	log.Debugf("Resetting limiter for %s", clientHandle)
	delete(jwtUserSessions, clientHandle)
}

func UpsertUser(username, jwtToken string) error {
	mu.Lock()
	defer mu.Unlock()

	uid, err := getUidFromJwtToken(jwtToken)
	if err != nil {
		return fmt.Errorf("could not get sonar uid from jwt token: %v", err)
	}
	jwtUserSessions[jwtToken] = User{UserName: username, UidSub: uid}

	return nil
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

func getUidFromJwtToken(tokenStr string) (string, error) {
	token, err := parseJwtToken(tokenStr)
	if err != nil {
		return "", fmt.Errorf("could not parse JWT token %s to get sonarqube UID: %w", tokenStr, err)
	}

	uid, err := token.Claims.GetSubject()
	if err != nil || uid == "" {
		return "", fmt.Errorf("failed to get sonarqube UID from session JWT subject: %w", err)
	}
	return uid, nil
}

func getTokenExpirationDate(tokenStr string) (time.Time, error) {
	token, err := parseJwtToken(tokenStr)
	if err != nil {
		return time.Time{}, fmt.Errorf("could not parse JWT token %s to get expiration date: %w", tokenStr, err)
	}

	expDate, err := token.Claims.GetExpirationTime()
	if err != nil {
		return time.Time{}, err
	}
	return expDate.Time, nil
}

// parseJwtToken takes a JWT token string and tries hard to parse it without failing for validity (because SonarQube's
// JWT secret key is unknown and cannot be set without changing the runtime behaviour)
func parseJwtToken(tokenStr string) (*jwt.Token, error) {
	token, err := jwt.Parse(
		tokenStr,
		func(token *jwt.Token) (any, error) { return []byte("unknownHS256SecretKey"), nil },
		jwt.WithValidMethods([]string{"HS256"}))
	if err != nil && token == nil {
		return nil, fmt.Errorf("failed to sufficently parse sonarqube session JWT: %w", err)
	}

	if token == nil {
		return nil, fmt.Errorf("failed to squeeze any information about sonarqube session JWT: %w", err)
	}

	if token.Claims == nil {
		return nil, fmt.Errorf("failed to refine claims from sonarube session JWT: %s", tokenStr)
	}
	return token, nil
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

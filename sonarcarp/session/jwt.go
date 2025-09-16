package session

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

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

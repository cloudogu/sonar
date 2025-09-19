package session

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func getTokenExpirationDate(tokenStr string) (time.Time, error) {
	tokenClaims, err := parseJwtToken(tokenStr)
	if err != nil {
		return time.Time{}, fmt.Errorf("could not parse JWT tokenClaims %s to get expiration date: %w", tokenStr, err)
	}

	expDate, err := tokenClaims.GetExpirationTime()
	if err != nil {
		return time.Time{}, err
	}
	return expDate.Time, nil
}

// parseJwtToken takes a JWT token string and tries hard to parse it without failing for validity (because SonarQube's
// JWT secret key is unknown and cannot be set without changing the runtime behaviour)

func parseJwtToken(tokenStr string) (claims jwt.RegisteredClaims, err error) {
	token, err := jwt.ParseWithClaims(
		tokenStr,
		jwt.RegisteredClaims{},
		func(token *jwt.Token) (any, error) { return []byte("unknownHS256SecretKey"), nil },
		jwt.WithValidMethods([]string{"HS256"}))
	if err != nil && token == nil {
		return claims, fmt.Errorf("failed to sufficently parse sonarqube session JWT: %w", err)
	}

	if token == nil {
		return claims, fmt.Errorf("failed to squeeze any information about sonarqube session JWT: %w", err)
	}

	if token.Claims == nil {
		return claims, fmt.Errorf("failed to refine claims from sonarube session JWT: %s", tokenStr)
	}
	theClaims := token.Claims.(jwt.RegisteredClaims)
	return theClaims, nil
}

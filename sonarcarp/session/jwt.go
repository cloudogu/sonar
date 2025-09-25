package session

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func getTokenExpirationDate(tokenStr string) (time.Time, error) {
	tokenClaims, err := parseJwtTokenToClaims(tokenStr)
	if err != nil {
		return time.Time{}, fmt.Errorf("could not parse JWT tokenClaims %s to get expiration date: %w", tokenStr, err)
	}

	expDate, err := tokenClaims.GetExpirationTime()
	if err != nil {
		return time.Time{}, err
	}
	return expDate.Time, nil
}

// parseJwtTokenToClaims takes a JWT token string and tries hard to parse it without failing for validity (because SonarQube's
// JWT secret key is unknown and cannot be set without changing the runtime behaviour)

func parseJwtTokenToClaims(tokenStr string) (claims jwt.Claims, err error) {
	token, err := jwt.Parse(
		tokenStr,
		func(token *jwt.Token) (any, error) { return []byte("unknownHS256SecretKey"), nil },
		jwt.WithValidMethods([]string{"HS256"}))
	if err != nil && token == nil {
		return claims, fmt.Errorf("failed to sufficently parse sonarqube session JWT: %w", err)
	}

	if token == nil {
		return claims, fmt.Errorf("failed to squeeze any information about sonarqube session JWT: %w", err)
	}

	if token.Claims == nil {
		return claims, fmt.Errorf("failed to refine claims from sonaqube session JWT: %s", tokenStr)
	}

	return token.Claims, nil
}

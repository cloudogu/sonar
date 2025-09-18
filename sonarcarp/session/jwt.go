package session

import (
	"fmt"

	"github.com/golang-jwt/jwt/v5"
)

// TODO Georg use me :D
func GetTokenUuidFromJwtToken(tokenStr string) (string, error) {
	claims, err := parseJwtToken(tokenStr)
	if err != nil {
		return "", fmt.Errorf("could not parse JWT token %s to get sonarqube UID: %w", tokenStr, err)
	}

	uid, err := claims.GetSubject()
	if err != nil || uid == "" {
		return "", fmt.Errorf("failed to get sonarqube UID from session JWT subject: %w", err)
	}
	return uid, nil
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

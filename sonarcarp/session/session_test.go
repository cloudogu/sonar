package session

import (
	"fmt"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const jwtExpiredAndInvalidSignature = "eyJhbGciOiJIUzI1NiJ9.eyJzc29MYXN0UmVmcmVzaFRpbWUiOjE3NTc0MjUwOTkwMzQsImxhc3RSZWZyZXNoVGltZSI6MTc1NzQyNTA5OTAzNywieHNyZlRva2VuIjoibWFmbnU3bWJxcDR2MWo1dW0wOTk3cnNncnEiLCJqdGkiOiJlNzdhNjgyZi1lYWYxLTQ4ZDktYjAyZS04ZDYwNDVkNTdiNTkiLCJzdWIiOiJjNzg4ZDI4Yi1kZTEwLTQ4YzktOWU1MS1hNjM1MDZmYmMxMmMiLCJpYXQiOjE3NTc0MjUwOTksImV4cCI6MTc1NzQyNTA5OX0.MCzGRGmoVr4FVB-87Bplf6a1cIoMU3N9nafE_wA1hYo"
const expectedSonarUid = "c788d28b-de10-48c9-9e51-a63506fbc12c"

func Test_getTokenValidDate(t *testing.T) {

	actual, err := getTokenExpirationDate(jwtExpiredAndInvalidSignature)

	require.NoError(t, err)
	assert.Equal(t, "asdf", actual)
}

func Test_getUidFromJwtToken(t *testing.T) {
	tests := []struct {
		name     string
		tokenStr string
		want     string
		wantErr  assert.ErrorAssertionFunc
	}{
		{
			"expired token returns subject",
			jwtExpiredAndInvalidSignature,
			expectedSonarUid,
			assert.NoError,
		},
		{
			"supervalid token returns subject",
			createValidJwtToken(t),
			expectedSonarUid,
			assert.NoError,
		},
		{
			"non-base64 gibberish returns error",
			"aösldkfjaösldkfjaösldkfjaösdlkfjasödlfkj",
			"",
			assert.Error,
		},
		{
			"base64 nonsense returns error",
			"aGVsbG8gd29ybGQ=.aGVsbG8gd29ybGQ=.aGVsbG8gd29ybGQ=",
			"",
			assert.Error,
		},
		{
			"jwt missing the sub as UID returns error",
			createJwtTokenWithoutSub(t),
			"",
			assert.Error,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := getUidFromJwtToken(tt.tokenStr)
			if !tt.wantErr(t, err, fmt.Sprintf("getUidFromJwtToken(%v)", tt.tokenStr)) {
				return
			}
			assert.Equalf(t, tt.want, got, "getUidFromJwtToken(%v)", tt.tokenStr)
		})
	}
}

func createValidJwtToken(t *testing.T) string {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"ssoLastRefreshTime": time.Now().Unix(),
		"lastRefreshTime":    time.Now().Unix(),
		"xsrfToken":          "mafnu7mbqp4v1j5um0Unimportant",
		"sub":                expectedSonarUid,
		"exp":                time.Now().Add(1 * time.Minute).Unix(),
	})

	tokenString, err := token.SignedString([]byte("hello secret"))
	require.NoError(t, err)

	return tokenString
}
func createJwtTokenWithoutSub(t *testing.T) string {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"ssoLastRefreshTime": time.Now().Unix(),
		"lastRefreshTime":    time.Now().Unix(),
		"xsrfToken":          "mafnu7mbqp4v1j5um0Unimportant",
		"yourSubHere":        "save $200 on sonarqube UIDs // nah sub should be just be missing here",
		"exp":                time.Now().Add(1 * time.Minute).Unix(),
	})

	tokenString, err := token.SignedString([]byte("hello secret"))
	require.NoError(t, err)

	return tokenString
}

package session

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const jwtExpiredAndInvalidSignature = "eyJhbGciOiJIUzI1NiJ9.eyJzc29MYXN0UmVmcmVzaFRpbWUiOjE3NTc0MjUwOTkwMzQsImxhc3RSZWZyZXNoVGltZSI6MTc1NzQyNTA5OTAzNywieHNyZlRva2VuIjoibWFmbnU3bWJxcDR2MWo1dW0wOTk3cnNncnEiLCJqdGkiOiJlNzdhNjgyZi1lYWYxLTQ4ZDktYjAyZS04ZDYwNDVkNTdiNTkiLCJzdWIiOiJjNzg4ZDI4Yi1kZTEwLTQ4YzktOWU1MS1hNjM1MDZmYmMxMmMiLCJpYXQiOjE3NTc0MjUwOTksImV4cCI6MTc1NzQyNTA5OX0.MCzGRGmoVr4FVB-87Bplf6a1cIoMU3N9nafE_wA1hYo"

func Test_getTokenValidDate(t *testing.T) {
	actual, err := getTokenExpirationDate(jwtExpiredAndInvalidSignature)

	require.NoError(t, err)
	expectedExpDate, _ := time.Parse(time.RFC3339, "2025-09-09T15:38:19+02:00")
	assert.Equal(t, expectedExpDate, actual)
}

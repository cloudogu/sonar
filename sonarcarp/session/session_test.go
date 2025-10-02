package session

import (
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const jwtExpiredAndInvalidSignature = "eyJhbGciOiJIUzI1NiJ9.eyJzc29MYXN0UmVmcmVzaFRpbWUiOjE3NTc0MjUwOTkwMzQsImxhc3RSZWZyZXNoVGltZSI6MTc1NzQyNTA5OTAzNywieHNyZlRva2VuIjoibWFmbnU3bWJxcDR2MWo1dW0wOTk3cnNncnEiLCJqdGkiOiJlNzdhNjgyZi1lYWYxLTQ4ZDktYjAyZS04ZDYwNDVkNTdiNTkiLCJzdWIiOiJjNzg4ZDI4Yi1kZTEwLTQ4YzktOWU1MS1hNjM1MDZmYmMxMmMiLCJpYXQiOjE1NTc0MjUwOTksImV4cCI6MTU1NzQyNTA5OX0.MCzGRGmoVr4FVB-87Bplf6a1cIoMU3N9nafE_wA1hYo"

func Test_getTokenValidDate(t *testing.T) {
	actual, err := getTokenExpirationDate(jwtExpiredAndInvalidSignature)

	require.NoError(t, err)
	expectedExpDate, _ := time.Parse(time.RFC3339, "2019-05-09T20:04:59+02:00")
	assert.Equal(t, expectedExpDate, actual)
}

func TestSaveJwtTokensFor(t *testing.T) {
	type args struct {
		casUsername string
		cookies     []*http.Cookie
	}
	tests := []struct {
		name        string
		args        args
		wantMapSize int
	}{
		{
			name: "save 2 cookies from 4 to map",
			args: args{
				casUsername: testUsername,
				cookies: []*http.Cookie{{Name: "A", Value: "uninteresting"},
					{Name: cookieNameJwtSession, Value: jwtExpiredAndInvalidSignature},
					{Name: cookieNameXsrfToken, Value: "helloxsrf"},
					{Name: "Z", Value: "uninteresting"},
				}},
			wantMapSize: 1,
		},
		{
			name: "save 0 cookies from 2 to map",
			args: args{
				casUsername: testUsername,
				cookies: []*http.Cookie{{Name: "A", Value: "uninteresting"},
					{Name: "Z", Value: "uninteresting"},
				}},
			wantMapSize: 0,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// when
			SaveJwtTokensFor(tt.args.casUsername, tt.args.cookies)
			// then
			assert.Len(t, jwtUserSessions, tt.wantMapSize)
			cleanUser(tt.args.casUsername)
		})
	}
}

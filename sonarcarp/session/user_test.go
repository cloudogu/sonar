package session

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestUser_String(t *testing.T) {
	type fields struct {
		UserName string
		JwtToken string
	}
	tests := []struct {
		name   string
		fields fields
		want   string
	}{
		{"full name and cut jwt token",
			fields{
				UserName: "pdampfschiffer",
				JwtToken: jwtExpiredAndInvalidSignature,
			},
			"pdampfschiffer:eyJzc29MYXN0UmVmcmVzaFRpbWUiOjE3...",
		},
		{"null user returns empty strings",
			fields{},
			"null",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			u := &User{
				UserName: tt.fields.UserName,
				JwtToken: tt.fields.JwtToken,
			}
			assert.Equalf(t, tt.want, u.String(), "String()")
		})
	}
}

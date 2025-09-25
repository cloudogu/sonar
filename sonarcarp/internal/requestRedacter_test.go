package internal

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRedactRequestHeaders(t *testing.T) {
	type args struct {
		original map[string][]string
	}
	cookieValue := []string{"JWT-SESSION=aösldkfjaöslkdfjaösldkfjaösdlf", "_cas-session=qpwoieurxl,mcv0qweruv"}
	AuthValue := []string{"Basic 1092384uwkjn234892ujk2342fd="}
	tests := []struct {
		name string
		args args
		want http.Header
	}{
		{"redacts regular named cookie header", args{map[string][]string{
			"Cock-a-doodle": {"kikiriki"},
			"Cookie":        cookieValue,
			"X-Cookies":     {"asdf"},
		}}, http.Header{
			"Cock-a-doodle": {"kikiriki"},
			"Cookie":        {"[Redacted]"},
			"X-Cookies":     {"asdf"}},
		},
		{"redacts uppercase named cookie header", args{map[string][]string{
			"Cock-a-doodle": {"kikiriki"},
			"COOKIE":        cookieValue,
			"X-Cookies":     {"asdf"},
		}}, http.Header{
			"Cock-a-doodle": {"kikiriki"},
			"COOKIE":        {"[Redacted]"},
			"X-Cookies":     {"asdf"}},
		},
		{"redacts Authorization header", args{map[string][]string{
			"Amazing-Header":   {"amazing!"},
			"Authorization":    AuthValue,
			"X-Authentication": {"Hello"},
		}}, http.Header{
			"Amazing-Header":   {"amazing!"},
			"Authorization":    {"[Redacted]"},
			"X-Authentication": {"Hello"}},
		},
		{"redacts cookie setting reponse header", args{map[string][]string{
			"Resp-Header":      {"amazing!"},
			"Set-cookie":       AuthValue,
			"X-Authentication": {"Hello"},
		}}, http.Header{
			"Resp-Header":      {"amazing!"},
			"Set-cookie":       {"[Redacted]"},
			"X-Authentication": {"Hello"}},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			originalHeader := http.Header(tt.args.original)
			assert.Equalf(t, tt.want, RedactRequestHeaders(originalHeader), "RedactRequestHeaders(%v)", tt.args.original)
		})
	}
}

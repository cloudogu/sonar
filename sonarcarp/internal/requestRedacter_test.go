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
		{"removes regular named cookie header", args{map[string][]string{
			"Cock-a-doodle": {"kikiriki"},
			"Cookies":       cookieValue,
			"X-Cookies":     {"asdf"},
		}}, http.Header{
			"Cock-a-doodle": {"kikiriki"},
			"X-Cookies":     {"asdf"}},
		},
		{"removes uppercase named cookie header", args{map[string][]string{
			"Cock-a-doodle": {"kikiriki"},
			"COOKIES":       cookieValue,
			"X-Cookies":     {"asdf"},
		}}, http.Header{
			"Cock-a-doodle": {"kikiriki"},
			"X-Cookies":     {"asdf"}},
		},
		{"removes Authorization header", args{map[string][]string{
			"Amazing-Header":   {"amazing!"},
			"Authorization":    AuthValue,
			"X-Authentication": {"Hello"},
		}}, http.Header{
			"Amazing-Header":   {"amazing!"},
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

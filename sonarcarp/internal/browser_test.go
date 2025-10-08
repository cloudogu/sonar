package internal

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestIsBrowserRequest(t *testing.T) {
	type args struct {
		userAgent string
	}
	tests := []struct {
		name string
		args args
		want bool
	}{
		{"Firefox returns true", args{userAgent: "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0"}, true},
		{"Chrome returns true", args{userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"}, true},
		{"Opera returns true", args{userAgent: "Opera/9.80 (Macintosh; Intel Mac OS X; U; en) Presto/2.2.15 Version/10.00"}, true},

		{"curl returns false", args{userAgent: "curl/7.64.1"}, false},
		{"golang default client returns false", args{userAgent: "Go-http-client/1.1"}, false},
	}
	for _, tt := range tests {
		req, _ := http.NewRequest(http.MethodGet, "http://url.invalid/", nil)
		req.Header.Set("User-Agent", tt.args.userAgent)
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, IsBrowserRequest(req), "IsBrowserRequest(%v)", req)
		})
	}
}

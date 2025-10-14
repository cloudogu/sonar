package internal

import (
	"net/http"
	"net/url"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestWithBackChannelLogoutRequestCheck(t *testing.T) {
	const testPath = "test"

	tests := []struct {
		name        string
		method      string
		contentType string
		path        string
		expBool     bool
	}{
		{
			name:        "valid backchannel logout request",
			method:      http.MethodPost,
			contentType: "application/x-www-form-urlencoded",
			path:        testPath,
			expBool:     true,
		},
		{
			name:        "valid backchannel logout request with trailing slash",
			method:      http.MethodPost,
			contentType: "application/x-www-form-urlencoded",
			path:        testPath + "/",
			expBool:     true,
		},
		{
			name:        "false on wrong http method",
			method:      http.MethodGet,
			contentType: "application/x-www-form-urlencoded",
			path:        testPath,
			expBool:     false,
		},
		{
			name:        "false on wrong content type",
			method:      http.MethodPost,
			contentType: "application/json",
			path:        testPath,
			expBool:     false,
		},
		{
			name:        "false on root path",
			method:      http.MethodPost,
			contentType: "application/x-www-form-urlencoded",
			path:        "/",
			expBool:     false,
		},
		{
			name:        "false on root subpath",
			method:      http.MethodPost,
			contentType: "application/x-www-form-urlencoded",
			path:        testPath + "/resource",
			expBool:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := &http.Request{
				Method: tt.method,
				URL:    &url.URL{Path: tt.path},
				Header: map[string][]string{"Content-Type": {tt.contentType}},
			}

			testFunc := WithBackChannelLogoutRequestCheck(testPath)

			assert.Equal(t, tt.expBool, testFunc(req))
		})
	}
}

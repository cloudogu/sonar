package internal

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIsBrowserRequest(t *testing.T) {
	tests := []struct {
		name    string
		headers map[string]string
		expBool bool
	}{
		{
			name: "No Auth header but user-agent",
			headers: map[string]string{
				"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36",
			},
			expBool: true,
		},
		{
			name: "Auth header but empty",
			headers: map[string]string{
				"Authorization": "",
			},
			expBool: true,
		},
		{
			name: "No browser client when Authorization header is set and not empty",
			headers: map[string]string{
				"Authorization": "test",
			},
			expBool: false,
		},
	}

	for _, tt := range tests {
		req, err := http.NewRequest("", "http://localhost", nil)
		require.NoError(t, err)

		for hKey, hValue := range tt.headers {
			req.Header.Set(hKey, hValue)
		}

		assert.Equal(t, tt.expBool, IsBrowserRequest(req))
	}
}

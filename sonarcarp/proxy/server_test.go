package proxy

import (
	"net/http"
	"testing"

	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewServer(t *testing.T) {
	server, err := NewServer(config.Configuration{
		Port:             8080,
		CarpResourcePath: "/carp-resources",
	})
	assert.NoError(t, err)
	assert.NotNil(t, server)
	assert.NotNil(t, server.Handler)
	assert.Equal(t, ":8080", server.Addr)
}

func Test_isBackChannelLogoutRequest(t *testing.T) {
	t.Run("should return false for any other requests", func(t *testing.T) {
		// given
		req, err := http.NewRequest(http.MethodPost, "http://10.12.14.16/sonar/qualityProfiles/123/", nil)
		require.NoError(t, err)

		// when
		actual := isBackChannelLogoutRequest()(req)

		// then
		require.NoError(t, err)
		assert.False(t, actual)
	})
	t.Run("should return true for POSTs on /sonar", func(t *testing.T) {
		// given
		req, err := http.NewRequest(http.MethodPost, "http://10.12.14.16/sonar/", nil)
		require.NoError(t, err)

		// when
		actual := isBackChannelLogoutRequest()(req)

		// then
		require.NoError(t, err)
		assert.True(t, actual)
	})
}

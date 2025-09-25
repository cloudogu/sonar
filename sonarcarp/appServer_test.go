package main

import (
	"context"
	"net/http"
	"testing"

	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewServer(t *testing.T) {
	server, err := NewServer(context.Background(), config.Configuration{
		Port:              8080,
		CarpResourcePaths: []string{"/sonar/css"},
	})
	assert.NoError(t, err)
	assert.NotNil(t, server)
	assert.NotNil(t, server.Handler)
	assert.Equal(t, ":8080", server.Addr)
}

func Test_isBackChannelLogoutRequest(t *testing.T) {
	t.Run("should always return false", func(t *testing.T) {
		// given
		req, err := http.NewRequest(http.MethodPost, "http://10.12.14.16/sonar/qualityProfiles/123/", nil)
		require.NoError(t, err)

		// when
		actual := isAlwaysDenyBackChannelLogoutRequest()(req)

		// then
		require.NoError(t, err)
		assert.False(t, actual)
	})
}

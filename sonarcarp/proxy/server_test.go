package proxy

import (
	"github.com/cloudogu/sonarcarp/config"
	"github.com/stretchr/testify/assert"
	"testing"
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

package main

import (
	"context"
	"testing"

	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/stretchr/testify/assert"
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

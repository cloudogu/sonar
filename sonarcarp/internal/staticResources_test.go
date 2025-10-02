package internal

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test_IsAuthenticationRequired(t *testing.T) {
	err := InitStaticResourceMatchers([]string{"/sonar/js/", "/sonar/images/", "/sonar/favicon.ico"})
	require.NoError(t, err)
	defer InitStaticResourceMatchers([]string{})

	tests := []struct {
		name string
		path string
		want bool
	}{
		{"true for first matcher", "/sonar/js/AlmSettingsInstanceSelector-BZLX0vJ4.js", true},
		{"true for nested path", "/sonar/images/alm/azure_grey.svg", true},
		{"true for last matcher", "/sonar/favicon.ico", true},
		{"false for UI endpoint", "/sonar/projects/create", false},
		{"false for API endpoint", "/sonar/api/features/list", false},
		{"false for basic traversal attack", "/sonar/js/../../sonar/api/features/list", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, IsInAlwaysAllowList(tt.path), "isAuthenticationRequired(%v)", tt.path)
		})
	}
}

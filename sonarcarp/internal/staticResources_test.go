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

func Test_IsInAlwaysAllowList_withDoguResourcePaths(t *testing.T) {
	// same values as carp-resource-paths in resources/carp.yml.tpl
	err := InitStaticResourceMatchers([]string{
		"/sonar/css/",
		"/sonar/favicon.ico",
		"/sonar/fonts/",
		"/sonar/images/",
		"/sonar/js/",
		"/sonar/batch/",
		"^/sonar/api/system/status$",
	})
	require.NoError(t, err)
	defer InitStaticResourceMatchers([]string{})

	tests := []struct {
		name string
		path string
		want bool
	}{
		{"true for static resource", "/sonar/js/AlmSettingsInstanceSelector-BZLX0vJ4.js", true},
		{"true for server status used by SonarQube for IDE", "/sonar/api/system/status", true},
		{"false for other system endpoint", "/sonar/api/system/info", false},
		{"false for server status sub path", "/sonar/api/system/status/foo", false},
		{"false for server status prefix", "/sonar/api/system/statusX", false},
		{"false for server status path in the middle of a path", "/sonar/api/foo/sonar/api/system/status", false},
		{"false for traversal attack to server status", "/sonar/api/system/status/../info", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, IsInAlwaysAllowList(tt.path), "IsInAlwaysAllowList(%v)", tt.path)
		})
	}
}

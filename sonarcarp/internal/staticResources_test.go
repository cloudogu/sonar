package internal

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_IsAuthenticationRequired(t *testing.T) {
	tests := []struct {
		name string
		path string
		want bool
	}{
		{"false for first matcher", "/sonar/js/AlmSettingsInstanceSelector-BZLX0vJ4.js", false},
		{"false for nested path", "/sonar/images/alm/azure_grey.svg", false},
		{"false for last matcher", "/sonar/favicon.ico", false},
		{"true for UI endpoint", "/sonar/projects/create", true},
		{"true for API endpoint", "/sonar/api/features/list", true},
		{"true for basic traversal attack", "/sonar/js/../../sonar/api/features/list", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, IsAuthenticationRequired(tt.path), "isAuthenticationRequired(%v)", tt.path)
		})
	}
}

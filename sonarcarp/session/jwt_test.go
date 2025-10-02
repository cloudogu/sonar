package session

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test_parseJwtTokenToClaims(t *testing.T) {
	t.Run("should return token with claims", func(t *testing.T) {
		// when
		actual, err := parseJwtTokenToClaims(jwtExpiredAndInvalidSignature)

		// then
		require.NoError(t, err)
		assert.NotNil(t, actual)
	})
}

package session

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestCleanJwtUserSessions(t *testing.T) {
	t.Run("should remove inserted data", func(t *testing.T) {
		// given
		upsertUser(testUsername, jwtExpiredAndInvalidSignature, "xsrfTokenORama")
		require.NotEmpty(t, jwtUserSessions[testUsername])

		// when
		cleanJwtUserSessions()

		//then
		require.Empty(t, jwtUserSessions[testUsername])
	})
}

func TestStartCleanJob(t *testing.T) {
	t.Run("should run cleaner goroutine", func(t *testing.T) {
		// given
		defer cleanJwtUserSessions()

		anotherTestCtx, cancelFunc := context.WithTimeout(context.Background(), 5*time.Second)
		defer anotherTestCtx.Done()
		defer cancelFunc()

		upsertUser(testUsername, jwtExpiredAndInvalidSignature, "xsrfTokenORama")
		require.NotEmpty(t, jwtUserSessions[testUsername])

		// when
		oneSecond := 1
		go startCleanJob(anotherTestCtx, oneSecond)
		time.Sleep(1500 * time.Millisecond)

		// then
		require.Empty(t, jwtUserSessions[testUsername])
	})
}

func TestInitCleanJob(t *testing.T) {
	// given
	defer cleanJwtUserSessions()

	anotherTestCtx, cancelFunc := context.WithTimeout(context.Background(), 5*time.Second)
	defer anotherTestCtx.Done()
	defer cancelFunc()

	upsertUser(testUsername, jwtExpiredAndInvalidSignature, "xsrfTokenORama")
	require.NotEmpty(t, jwtUserSessions[testUsername])

	// when
	oneSecond := 1
	InitCleanJob(anotherTestCtx, oneSecond)
	time.Sleep(1500 * time.Millisecond)

	// then
	require.Empty(t, jwtUserSessions[testUsername])
}

package throttling

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/cloudogu/sonar/sonarcarp/internal"
	"golang.org/x/time/rate"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/cloudogu/sonar/sonarcarp/config"
)

const maxTokens = 3

func TestThrottlingHandler(t *testing.T) {
	limiterConfig := config.Configuration{LimiterTokenRate: 1, LimiterBurstSize: maxTokens}
	ctx := context.TODO()

	cleanUp := func(server *httptest.Server) {
		server.Close()
		clients = make(map[string]*rate.Limiter)
	}

	t.Run("Throttle too many requests in short time", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusUnauthorized)
		}

		throttlingHandler := NewThrottlingHandler(ctx, limiterConfig, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			throttlingHandler.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "testIP")
		req.SetBasicAuth("test", "test")

		var found bool

		tooMany := 2
		for i := 0; i < maxTokens+tooMany; i++ {
			resp, lErr := server.Client().Do(req)
			assert.NoError(t, lErr)

			t.Log(i, resp.StatusCode)
			if resp.StatusCode == http.StatusTooManyRequests {
				found = true
				break
			}
		}

		assert.True(t, found)
	})

	t.Run("never throttle basic auth requests that return with HTTP 2xx (exceptions apply)", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			assert.Equal(t, request.URL.String(), "/sonar/projects/create")
			writer.WriteHeader(http.StatusOK)
		}

		throttlingHandler := NewThrottlingHandler(ctx, limiterConfig, handler)

		server := httptest.NewServer(throttlingHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL+"/sonar/projects/create", nil)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "testIP")
		req.SetBasicAuth("test", "test")

		for i := 0; i < maxTokens; i++ {
			resp, lErr := server.Client().Do(req)
			assert.NoError(t, lErr)
			assert.Equal(t, http.StatusOK, resp.StatusCode)
		}
		assert.Empty(t, clients) // HTTP200 leads to limiter resetting (== deletion)
	})

	t.Run("never throttle static resource requests that always return with HTTP 2xx", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusOK)
		}
		err := internal.InitStaticResourceMatchers([]string{"/sonar/js/"})
		require.NoError(t, err)

		throttlingHandler := NewThrottlingHandler(ctx, limiterConfig, handler)

		server := httptest.NewServer(throttlingHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL+"/sonar/js/something.js", nil)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "testIP")
		req.SetBasicAuth("test", "test")

		for i := 0; i < 3; i++ { // respect the upper limiter configuration...
			resp, lErr := server.Client().Do(req)
			assert.NoError(t, lErr)
			assert.Equal(t, http.StatusOK, resp.StatusCode)
		}
		assert.Empty(t, clients)
	})

	t.Run("Return error when invalid BasicAuth is provided", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusUnauthorized)
		}

		throttlingHandler := NewThrottlingHandler(ctx, limiterConfig, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			throttlingHandler.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "testIP")

		resp, lErr := server.Client().Do(req)
		assert.NoError(t, lErr)
		assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)
	})

	t.Run("Refresh Tokens after throttling", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusUnauthorized)
		}

		throttlingHandler := NewThrottlingHandler(ctx, limiterConfig, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			throttlingHandler.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "testIP")
		req.SetBasicAuth("test", "test")

		clientCtx, cancel := context.WithTimeout(context.TODO(), 5*time.Second)
		defer cancel()

		// Using the same limiter config for client means, server can refresh tokens
		clientLimiter := rate.NewLimiter(rate.Limit(limiterConfig.LimiterTokenRate), limiterConfig.LimiterBurstSize)

		for i := 0; i < 5; i++ {
			lErr := clientLimiter.Wait(clientCtx)
			assert.NoError(t, lErr)

			resp, lErr := server.Client().Do(req)
			assert.NoError(t, lErr)

			t.Log(i, resp.StatusCode)
			assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)
		}
	})

	t.Run("Reset throttling after successful try", func(t *testing.T) {
		reqCounter := 0

		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			if reqCounter >= (limiterConfig.LimiterBurstSize - 1) {
				writer.WriteHeader(http.StatusOK)
				reqCounter = 0
				return
			}

			writer.WriteHeader(http.StatusUnauthorized)
			reqCounter++
		}

		throttlingHandler := NewThrottlingHandler(ctx, limiterConfig, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			throttlingHandler.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "testIP")
		req.SetBasicAuth("test", "test")

		var found bool

		for i := 0; i < 10; i++ {
			resp, lErr := server.Client().Do(req)
			assert.NoError(t, lErr)

			t.Log(i, resp.StatusCode)
			if resp.StatusCode == http.StatusTooManyRequests {
				found = true
				break
			}
		}

		assert.False(t, found)
	})

	t.Run("CleanUp clients", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusUnauthorized)
		}

		lCtx, cancel := context.WithTimeout(context.TODO(), 3*time.Second)
		defer cancel()

		limiterCleanInterval := 1

		inputConfig := config.Configuration{
			LimiterTokenRate:     limiterConfig.LimiterTokenRate,
			LimiterBurstSize:     limiterConfig.LimiterBurstSize,
			LimiterCleanInterval: limiterCleanInterval,
		}

		throttlingHandler := NewThrottlingHandler(lCtx, inputConfig, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			throttlingHandler.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "testIP")
		req.SetBasicAuth("test", "test")

		resp, lErr := server.Client().Do(req)
		require.NoError(t, lErr)
		require.Equal(t, http.StatusUnauthorized, resp.StatusCode)

		// Evaluate cleanup clients
		require.True(t, len(clients) > 0)

		tick := time.Tick(time.Duration(limiterCleanInterval) * time.Second)

		for {
			select {
			case <-lCtx.Done():
				assert.Fail(t, "Test failed because of timeout")
			case <-tick:
				if len(clients) == 0 {
					return
				}
			}
		}
	})
}

func Test_inUnauthenticatedEndpointList(t *testing.T) {
	tests := []struct {
		name string
		path string
		want bool
	}{
		{"return true", "/api/server/version", true},
		{"return false", "/api/alm_settings/get_binding", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, inUnauthenticatedEndpointList(tt.path), "inUnauthenticatedEndpointList(%v)", tt.path)
		})
	}
}

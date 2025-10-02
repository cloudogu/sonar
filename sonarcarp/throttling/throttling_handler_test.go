package throttling

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"golang.org/x/time/rate"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/cloudogu/sonar/sonarcarp/internal"
)

const maxTokens = 3

var testCtx = context.Background()

func TestThrottlingHandler(t *testing.T) {
	testCfg := config.Configuration{
		PrincipalHeader:   "X-Forwarded-Login",
		NameHeader:        "X-Forwarded-Name",
		MailHeader:        "X-Forwarded-Email",
		RoleHeader:        "X-Forwarded-Groups",
		LimiterTokenRate:  1,
		LimiterBurstSize:  maxTokens,
		CarpResourcePaths: []string{"/sonar/js/"},
	}

	err := internal.InitStaticResourceMatchers([]string{"/sonar/js/"})
	require.NoError(t, err)
	defer internal.InitStaticResourceMatchers([]string{})

	cleanUp := func(server *httptest.Server) {
		server.Close()
		clients = make(map[string]*rate.Limiter)
	}

	t.Run("Throttle too many requests in short time", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusUnauthorized)
		}

		sut := NewThrottlingHandler(testCtx, testCfg, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			sut.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL+"/sonar/projects/create", nil)
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

		sut := NewThrottlingHandler(testCtx, testCfg, handler)

		server := httptest.NewServer(sut)
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

		sut := NewThrottlingHandler(testCtx, testCfg, handler)

		server := httptest.NewServer(sut)
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
		assert.InDelta(t, clients["testIP:test"].Tokens(), 3.0, 0.1)
	})

	t.Run("Return error when invalid BasicAuth is provided", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusUnauthorized)
		}

		sut := NewThrottlingHandler(testCtx, testCfg, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			sut.ServeHTTP(writer, request)
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

		sut := NewThrottlingHandler(testCtx, testCfg, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			sut.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer cleanUp(server)

		clientCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		req = req.WithContext(clientCtx)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "anotherIP")
		req.SetBasicAuth("test", "test")

		// Test Idea:
		// Try 3 times with "401 not found" which exhausts all 3 tokens (testCfg.LimiterBurstSize).
		// This should lead to one "429 too many requests".
		// Then, gain time to replenish at least on token so a previous HTTP 401 can take place
		// Result: Replenishing tokens could be proved
		for i := 0; i < 5; i++ {
			resp, lErr := (&http.Client{}).Do(req)
			assert.NoError(t, lErr)
			t.Log(i, resp.StatusCode)

			switch i {
			case 0:
				fallthrough
			case 1:
				fallthrough
			case 2:
				assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)
			case 3:
				assert.Equal(t, http.StatusTooManyRequests, resp.StatusCode)
				time.Sleep(2 * time.Second)
			default:
				// tadaaa! same as runs 0,1,2
				assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)
				time.Sleep(1 * time.Second)
			}
		}
	})
	t.Run("Full throttling because malicious header attack", func(t *testing.T) {
		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			writer.WriteHeader(http.StatusTeapot)
			t.Fatalf("the request should not have passed through")
		}

		sut := NewThrottlingHandler(testCtx, testCfg, handler)

		var ctxHandler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			sut.ServeHTTP(writer, request)
		}

		server := httptest.NewServer(ctxHandler)
		defer cleanUp(server)

		req, err := http.NewRequest(http.MethodGet, server.URL, nil)
		require.NoError(t, err)

		req.Header.Set(_HttpHeaderXForwardedFor, "10.20.30.40") // this request comes over the nginx dogu so this header must be set, mustn't it?
		req.Header.Set("X-Forwarded-Login", "baddy.mcbadface")

		resp, lErr := server.Client().Do(req)
		assert.NoError(t, lErr)

		// block right away on the first request
		assert.Equal(t, http.StatusTooManyRequests, resp.StatusCode)
	})

	t.Run("Reset throttling after successful try", func(t *testing.T) {
		reqCounter := 0

		var handler http.HandlerFunc = func(writer http.ResponseWriter, request *http.Request) {
			if reqCounter >= (testCfg.LimiterBurstSize - 1) {
				writer.WriteHeader(http.StatusOK)
				reqCounter = 0
				return
			}

			writer.WriteHeader(http.StatusUnauthorized)
			reqCounter++
		}

		throttlingHandler := NewThrottlingHandler(testCtx, testCfg, handler)

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
			LimiterTokenRate:     testCfg.LimiterTokenRate,
			LimiterBurstSize:     testCfg.LimiterBurstSize,
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

func Test_hasAlreadySonarQubeAuthHeaders(t *testing.T) {
	cfg := config.Configuration{
		PrincipalHeader: "X-Forwarded-Login",
		NameHeader:      "X-Forwarded-Name",
		MailHeader:      "X-Forwarded-Email",
		RoleHeader:      "X-Forwarded-Groups",
	}
	type args struct {
		header http.Header
	}
	tests := []struct {
		name string
		args args
		want bool
	}{
		{"return true for single unwanted header", args{http.Header{"X-Forwarded-Login": []string{"test"}}}, true},
		{"return true for multiple headers", args{http.Header{
			"X-Forwarded-Login":  []string{"test"},
			"X-Forwarded-Name":   []string{"test"},
			"X-Forwarded-Email":  []string{"test"},
			"X-Forwarded-Groups": []string{"test"}}}, true},
		{"return true for uppercase headers", args{http.Header{
			"X-FORWARDED-LOGIN": []string{"test"}}}, true},
		{"return true for lowercase headers", args{http.Header{
			"x-forwarded-login":  []string{"test"},
			"x-forwarded-name":   []string{"test"},
			"x-forwarded-email":  []string{"test"},
			"x-forwarded-groups": []string{"test"}}}, true},

		{"return false for similar but not quite", args{http.Header{"y-Forwarded-Login": []string{"test"}}}, false},
		{"return false no headers", args{http.Header{}}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, hasAlreadySonarQubeAuthHeaders(cfg, tt.args.header), "hasAlreadySonarQubeAuthHeaders(%v, %v)", cfg, tt.args.header)
		})
	}
}

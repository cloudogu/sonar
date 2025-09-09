package throttling

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"

	"github.com/op/go-logging"

	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/cloudogu/sonar/sonarcarp/internal"
	carplog "github.com/cloudogu/sonar/sonarcarp/logging"
)

const _HttpHeaderXForwardedFor = "X-Forwarded-For"

const (
	// LimiterTokenRate contains the tokens per second that each client will receive to refill the limiter bucket.
	LimiterTokenRate = 1
	// LimiterBurstSize contains the maximum number of tokens until requests get throttled.
	LimiterBurstSize = 150
	// LimiterCleanInterval contains the default time window in seconds between all clients will be checked if they can
	// be reset by checking if at least one single token is available.
	LimiterCleanInterval = 300
)

var log = logging.MustGetLogger("proxy")

var (
	mu      sync.RWMutex
	clients = make(map[string]*rate.Limiter)
)

// NewThrottlingHandler creates a drop-in HTTP handler that returns HTTP 429 "Too Many Requests" if a client creates too
// many requests whose response is HTTP 401 "Unauthorized".
//
// Using the Leaky-Bucket-algorithm, this handler will take a configuration which configures a time window, burst size,
// and token refresh rate to set up the throttle agent.
func NewThrottlingHandler(ctx context.Context, configuration config.Configuration, handler http.Handler) http.Handler {
	limiterTokenRateInSecs := configuration.LimiterTokenRate
	if limiterTokenRateInSecs == 0 {
		limiterTokenRateInSecs = LimiterTokenRate
	}

	limiterBurstSize := configuration.LimiterBurstSize
	if limiterBurstSize == 0 {
		limiterBurstSize = LimiterBurstSize
	}

	limiterCleanIntervalInSecs := configuration.LimiterCleanInterval
	if limiterCleanIntervalInSecs == 0 {
		limiterCleanIntervalInSecs = LimiterCleanInterval
	}

	go startCleanJob(ctx, limiterCleanIntervalInSecs)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Debugf("ThrottlingHandler was hit")
		statusWriter := carplog.NewStatusResponseWriter(w, r, "throttler")

		authenticationRequired := internal.IsAuthenticationRequired(r.URL.Path)
		if !authenticationRequired {
			log.Debugf("Proxy: %s request to %s does not need authentication", r.Method, r.URL.String())
			handler.ServeHTTP(statusWriter, r)
			return
		}

		username, _, ok := r.BasicAuth()
		if !ok {
			username = "sonarcarp.throttling@ces.invalid"
		}

		forwardedIpAddrRaw := r.Header.Get(_HttpHeaderXForwardedFor)
		isCesInternalDoguCall := forwardedIpAddrRaw == ""
		if isCesInternalDoguCall {
			log.Debugf("No %s header is set for request. Forwarding internal dogu request without throttling", _HttpHeaderXForwardedFor)
			handler.ServeHTTP(statusWriter, r)
			return
		}

		// go reverse proxy may add additional IP addresses from localhost. We need to take the right one.
		forwardedIpAddresses := strings.Split(forwardedIpAddrRaw, ",")
		initialForwardedIpAddress := ""
		if len(forwardedIpAddresses) > 0 {
			initialForwardedIpAddress = strings.TrimSpace(forwardedIpAddresses[0])
		}

		log.Debugf("Extracted IP  %s from %s for throttling: %s", initialForwardedIpAddress, _HttpHeaderXForwardedFor, username)

		ipUsernameId := fmt.Sprintf("%s:%s", initialForwardedIpAddress, username)
		limiter := getOrCreateLimiter(ipUsernameId, limiterTokenRateInSecs, limiterBurstSize)

		// Consume one token AND check if r is still allowed
		if !limiter.Allow() {
			log.Infof("Throttle request to %s from user %s with ip %s", r.RequestURI, username, forwardedIpAddresses)

			http.Error(statusWriter, http.StatusText(http.StatusTooManyRequests), http.StatusTooManyRequests)
			return
		}

		log.Debugf("Client %s has %.1f tokens left", ipUsernameId, limiter.Tokens())

		handler.ServeHTTP(statusWriter, r)

		log.Debugf("Status for %s returned with %d", r.URL.String(), statusWriter.HttpStatusCode())

		if statusWriter.HttpStatusCode() >= 200 && statusWriter.HttpStatusCode() < 400 {
			cleanClient(ipUsernameId)
		}

	})
}

func inUnauthenticatedEndpointList(path string) bool {
	return strings.HasSuffix(path, "api/server/version")
}

func getOrCreateLimiter(ip string, limiterTokenRate, limiterBurstSize int) *rate.Limiter {
	mu.Lock()
	defer mu.Unlock()

	l, ok := clients[ip]
	if !ok {
		log.Debugf("Create new limiter for %s", ip)
		l = rate.NewLimiter(rate.Limit(limiterTokenRate), limiterBurstSize)
		clients[ip] = l
	}

	return l
}

func cleanClient(clientHandle string) {
	mu.Lock()
	defer mu.Unlock()

	log.Debugf("Resetting limiter for %s", clientHandle)
	delete(clients, clientHandle)
}

func cleanClients() {
	mu.Lock()
	defer mu.Unlock()

	numberCleaned := 0
	for client, limiter := range clients {
		if limiter.Allow() {
			log.Debugf("Cleaning limiter for %s", client)
			delete(clients, client)
		}
		numberCleaned++
	}

	if numberCleaned > 0 {
		log.Infof("Removed limiters for %d clients", numberCleaned)
	}
}

func startCleanJob(ctx context.Context, cleanInterval int) {
	tick := time.Tick(time.Duration(cleanInterval) * time.Second)

	for {
		select {
		case <-ctx.Done():
			log.Info("Context done. Stop throttling cleanup job")
			return
		case <-tick:
			log.Info("Start cleanup for clients in throttling map")
			cleanClients()
		}
	}
}

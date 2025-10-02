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
)

// _HttpHeaderXForwardedFor contains a request header identifying the original client address through a reverse proxy.
// The value may contain a list of hosts/IP addresses.
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

var log = logging.MustGetLogger("throttling")

var (
	mu      sync.RWMutex
	clients = make(map[string]*rate.Limiter)
)

// NewThrottlingHandler creates a drop-in HTTP handler that returns HTTP 429 "Too Many Requests" if a client creates too
// many requests whose response is HTTP 401 "Unauthorized".
//
// Using the Leaky-Bucket-algorithm, this handler will take a configuration which configures a time window, burst size,
// and token refresh rate to set up the throttle agent.
func NewThrottlingHandler(ctx context.Context, cfg config.Configuration, handler http.Handler) http.Handler {
	limiterTokenRateInSecs := cfg.LimiterTokenRate
	if limiterTokenRateInSecs == 0 {
		limiterTokenRateInSecs = LimiterTokenRate
	}

	limiterBurstSize := cfg.LimiterBurstSize
	if limiterBurstSize == 0 {
		limiterBurstSize = LimiterBurstSize
	}

	limiterCleanIntervalInSecs := cfg.LimiterCleanInterval
	if limiterCleanIntervalInSecs == 0 {
		limiterCleanIntervalInSecs = LimiterCleanInterval
	}

	go startCleanJob(ctx, limiterCleanIntervalInSecs)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Debugf("throttling middleware was called for %s", r.URL.String())
		statusWriter := internal.NewStatusResponseWriter(w, r, "throttler")

		forwardedIpAddrRaw := r.Header.Get(_HttpHeaderXForwardedFor)
		username, _, ok := r.BasicAuth()
		if !ok {
			username = "sonarcarp.throttling@ces.invalid"
		}
		forwardedIpAddresses, ipUsernameId, limiter := createLimiter(forwardedIpAddrRaw, username, limiterTokenRateInSecs, limiterBurstSize)

		// check BEFORE any other requests pass through the system to avoid that SonarQube issues any form of session cookie
		if hasAlreadySonarQubeAuthHeaders(cfg, r.Header) {
			log.Errorf("Found request with malicious SQ authentication headers from %s, %s to URL %s: Throttle all requests for now", forwardedIpAddresses, ipUsernameId, r.URL.String())

			for limiter.Allow() {
			} // consume all tokens for good measure against the hacker client

			http.Error(statusWriter, http.StatusText(http.StatusTooManyRequests), http.StatusTooManyRequests)
			return
		}

		authenticationNoRequired := internal.IsInAlwaysAllowList(r.URL.Path)
		if authenticationNoRequired {
			log.Debugf("Throttling: %s request to %s does not need authentication", r.Method, r.URL.String())
			handler.ServeHTTP(statusWriter, r)
			return
		}

		isCesInternalDoguCall := forwardedIpAddrRaw == ""
		if isCesInternalDoguCall {
			log.Debugf("No %s header is set for request. Forwarding internal dogu request without throttling", _HttpHeaderXForwardedFor)
			handler.ServeHTTP(statusWriter, r)
			return
		}

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

func hasAlreadySonarQubeAuthHeaders(cfg config.Configuration, header http.Header) bool {
	usernameHeader := strings.ToLower(cfg.PrincipalHeader)
	nameHeader := strings.ToLower(cfg.NameHeader)
	mailHeader := strings.ToLower(cfg.MailHeader)
	groupsHeader := strings.ToLower(cfg.RoleHeader)

	for key := range (map[string][]string)(header) {
		switch strings.ToLower(key) {
		case usernameHeader:
			fallthrough
		case nameHeader:
			fallthrough
		case mailHeader:
			fallthrough
		case groupsHeader:
			return true
		}
	}

	return false
}

func createLimiter(forwardedIpAddrRaw string, username string, limiterTokenRateInSecs int, limiterBurstSize int) ([]string, string, *rate.Limiter) {
	// go reverse proxy may add additional IP addresses from localhost. We need to take the right one.
	forwardedIpAddresses := strings.Split(forwardedIpAddrRaw, ",")
	initialForwardedIpAddress := ""
	if len(forwardedIpAddresses) > 0 {
		initialForwardedIpAddress = strings.TrimSpace(forwardedIpAddresses[0])
	}

	ipUsernameId := fmt.Sprintf("%s:%s", initialForwardedIpAddress, username)
	limiter := getOrCreateLimiter(ipUsernameId, limiterTokenRateInSecs, limiterBurstSize)
	return forwardedIpAddresses, ipUsernameId, limiter
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

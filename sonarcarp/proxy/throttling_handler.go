package proxy

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/cloudogu/sonar/sonarcarp/config"
	"golang.org/x/time/rate"
)

const _HttpHeaderXForwardedFor = "X-Forwarded-For"

var (
	mu      sync.RWMutex
	clients = make(map[string]*rate.Limiter)
)

const (
	LimiterTokenRate     = 1
	LimiterBurstSize     = 150
	LimiterCleanInterval = 300
)

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

	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		// TODO stuff here
		/*
			authenticationUnnecessary := isAuthenticationRequired(p.staticResourceMatchers, r.URL.Path)
			if authenticationUnnecessary {
				p.forwarder.ServeHTTP(w, r)
				return
			}
		*/

		username, _, ok := request.BasicAuth()
		if !ok {
			username = "john.throttle.doe@ces.invalid"
		}

		forwardedIpAddrRaw := request.Header.Get(_HttpHeaderXForwardedFor)
		isCesInternalDoguCall := forwardedIpAddrRaw == ""
		if isCesInternalDoguCall {
			log.Debugf("No %s header is set for request. Forwarding internal dogu request without throttling", _HttpHeaderXForwardedFor)
			handler.ServeHTTP(writer, request)
			return
		}

		// go reverse proxy may add additional IP addresses from localhost. We need to take the right one.
		forwardedIpAddresses := strings.Split(forwardedIpAddrRaw, ",")
		initialForwardedIpAddress := ""
		if len(forwardedIpAddresses) > 0 {
			initialForwardedIpAddress = strings.TrimSpace(forwardedIpAddresses[0])
		}

		log.Debugf("Extracted ip from %s for throttling: %s", _HttpHeaderXForwardedFor, username)

		ipUsernameId := fmt.Sprintf("%s:%s", initialForwardedIpAddress, username)
		limiter := getOrCreateLimiter(ipUsernameId, limiterTokenRateInSecs, limiterBurstSize)

		statusWriter := &statusResponseWriter{
			ResponseWriter: writer,
			httpStatusCode: http.StatusOK,
		}

		if !limiter.Allow() {
			log.Infof("Throttle request to %s from user %s with ip %s", request.RequestURI, username, initialForwardedIpAddress)

			http.Error(statusWriter, http.StatusText(http.StatusTooManyRequests), http.StatusTooManyRequests)
			return
		}

		log.Debugf("Client %s has %.1f tokens left", ipUsernameId, limiter.Tokens())

		handler.ServeHTTP(statusWriter, request)

		log.Debugf("Status for %s returned with %d", request.URL.String(), statusWriter.httpStatusCode)

		if statusWriter.httpStatusCode >= 200 && statusWriter.httpStatusCode < 400 {
			log.Debugf("Status sufficiently okay - resetting limiter for %s", ipUsernameId)
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

func cleanClient(ip string) {
	mu.Lock()
	defer mu.Unlock()

	delete(clients, ip)
}

func cleanClients() {
	mu.Lock()
	defer mu.Unlock()

	for client, limiter := range clients {
		if limiter.Allow() {
			log.Debugf("Cleaning limiter for %s", client)
			delete(clients, client)
		}
	}
}

func startCleanJob(ctx context.Context, cleanInterval int) {
	tick := time.Tick(time.Duration(cleanInterval) * time.Second)

	for {
		select {
		case <-ctx.Done():
			log.Infof("Context done - stop throttling cleanup job")
			return
		case <-tick:
			log.Info("Start cleanup for clients in throttling map")
			cleanClients()
		}
	}
}

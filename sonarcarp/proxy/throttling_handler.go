package proxy

import (
	"context"
	"fmt"
	"github.com/cloudogu/sonar/sonarcarp/config"
	"golang.org/x/time/rate"
	"net/http"
	"strings"
	"sync"
	"time"
)

const _HttpHeaderXForwardedFor = "X-Forwarded-For"
const _DefaultCleanInterval = 300

var (
	mu      sync.RWMutex
	clients = make(map[string]*rate.Limiter)
)

const (
	LimiterTokenRate     = 50
	LimiterBurstSize     = 150
	LimiterCleanInterval = 300
)

func NewThrottlingHandler(ctx context.Context, configuration config.Configuration, handler http.Handler) http.Handler {
	go startCleanJob(ctx, LimiterCleanInterval)

	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		username := "asdf" // TODO: extract username

		forwardedIpAddrRaw := request.Header.Get(_HttpHeaderXForwardedFor)
		isCesInternalDoguCall := forwardedIpAddrRaw == ""
		if isCesInternalDoguCall {
			log.Debugf("No %s header is set for request. Forwarding internal dogu request", _HttpHeaderXForwardedFor)
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

		statusWriter := &statusResponseWriter{
			ResponseWriter: writer,
			httpStatusCode: http.StatusOK,
		}

		ipUsernameId := fmt.Sprintf("%s:%s", initialForwardedIpAddress, username)
		limiter := getOrCreateLimiter(ipUsernameId, LimiterTokenRate, LimiterBurstSize)

		if !limiter.Allow() {
			log.Infof("Throttle request to %s from user %s with ip %s", request.RequestURI, username, initialForwardedIpAddress)

			http.Error(statusWriter, http.StatusText(http.StatusTooManyRequests), http.StatusTooManyRequests)
			return
		}

		log.Debugf("User %s with IP address %s has %.1f tokens left", username, initialForwardedIpAddress, limiter.Tokens())

		handler.ServeHTTP(statusWriter, request)

		if statusWriter.httpStatusCode >= 200 && statusWriter.httpStatusCode < 400 {
			log.Debugf("Status is %v - cleaning requests", statusWriter.httpStatusCode)
			cleanClient(ipUsernameId)
		}

	})
}

func getOrCreateLimiter(ip string, limiterTokenRate, limiterBurstSize int) *rate.Limiter {
	mu.Lock()
	defer mu.Unlock()

	l, ok := clients[ip]
	if !ok {
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
			delete(clients, client)
		}
	}
}

func startCleanJob(ctx context.Context, cleanInterval int) {
	if cleanInterval == 0 {
		cleanInterval = _DefaultCleanInterval
	}

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

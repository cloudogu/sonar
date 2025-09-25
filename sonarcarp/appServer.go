package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"net/url"
	"path"
	"strconv"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/cloudogu/sonar/sonarcarp/proxy"
	"github.com/cloudogu/sonar/sonarcarp/session"
	"github.com/cloudogu/sonar/sonarcarp/throttling"
)

func NewServer(ctx context.Context, configuration config.Configuration) (*http.Server, error) {
	casClient, err := NewCasClientFactory(configuration)
	if err != nil {
		return nil, fmt.Errorf("failed to create CAS client during carp server start: %w", err)
	}

	headers := proxy.AuthorizationHeaders{
		Principal: configuration.PrincipalHeader,
		Role:      configuration.RoleHeader,
		Mail:      configuration.MailHeader,
		Name:      configuration.NameHeader,
	}

	err = internal.InitStaticResourceMatchers(configuration.CarpResourcePaths)
	if err != nil {
		return nil, fmt.Errorf("failed to static resource matcher init during carp server start: %w", err)
	}

	session.InitCleanJob(ctx, session.JwtSessionCleanInterval) // TODO configure interval

	router := http.NewServeMux()

	pHandler, err := proxy.CreateProxyHandler(
		headers,
		casClient,
		configuration,
	)

	throttlingHandler := throttling.NewThrottlingHandler(ctx, configuration, pHandler)

	bcLogoutHandler := session.Middleware(throttlingHandler, configuration, casClient)

	logHandler := internal.Middleware(bcLogoutHandler, "throttling")

	router.Handle("/sonar/", logHandler)

	log.Debugf("starting server on port %d", configuration.Port)

	return &http.Server{
		Addr:    ":" + strconv.Itoa(configuration.Port),
		Handler: router,
	}, nil
}

func NewCasClientFactory(cfg config.Configuration) (*cas.Client, error) {
	casUrl, err := url.Parse(cfg.CasUrl)
	if err != nil {
		return nil, fmt.Errorf("failed to parse cas url: %s: %w", cfg.CasUrl, err)
	}

	// CAS needs something like https://fqdn/sonar to register a dogu as proper CAS client dogu.
	sonarUrlWithContext, err := url.JoinPath(cfg.ServiceUrl, cfg.AppContextPath)
	if err != nil {
		return nil, fmt.Errorf("failed to join sonarqube context path for CAS clienting: %s: %w", cfg.CasUrl, err)
	}

	serviceUrl, err := url.Parse(sonarUrlWithContext)
	if err != nil {
		return nil, fmt.Errorf("failed to parse service url: %s: %w", sonarUrlWithContext, err)
	}

	urlScheme := cas.NewDefaultURLScheme(casUrl)
	urlScheme.ServiceValidatePath = path.Join("p3", "serviceValidate")

	httpClient := &http.Client{}
	if cfg.SkipSSLVerification {
		transport := &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		}
		httpClient.Transport = transport
	}

	return cas.NewClient(&cas.Options{
		URL:             serviceUrl,
		Client:          httpClient,
		URLScheme:       urlScheme,
		IsLogoutRequest: isAlwaysDenyBackChannelLogoutRequest(),
	}), nil
}

// isAlwaysDenyBackChannelLogoutRequest returns always false to circumvent go-cas' buggy backchannel logout request
// detection. Instead sonarcarp implements its own detection in session.Middleware.
func isAlwaysDenyBackChannelLogoutRequest() func(r *http.Request) bool {
	return func(r *http.Request) bool {
		return false
	}
}

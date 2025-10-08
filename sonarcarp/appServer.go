package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"net/url"
	"path"
	"strconv"

	"github.com/cloudogu/go-cas/v2"

	"github.com/cloudogu/sonar/sonarcarp/casfilter"
	"github.com/cloudogu/sonar/sonarcarp/config"
	"github.com/cloudogu/sonar/sonarcarp/internal"
	"github.com/cloudogu/sonar/sonarcarp/proxy"
	"github.com/cloudogu/sonar/sonarcarp/session"
	"github.com/cloudogu/sonar/sonarcarp/throttling"
)

func NewServer(ctx context.Context, cfg config.Configuration) (*http.Server, error) {
	casBrowserClient, casRestClient, err := NewCasClients(cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create CAS client during carp server start: %w", err)
	}

	headers := proxy.AuthorizationHeaders{
		Principal: cfg.PrincipalHeader,
		Role:      cfg.RoleHeader,
		Mail:      cfg.MailHeader,
		Name:      cfg.NameHeader,
	}

	err = internal.InitStaticResourceMatchers(cfg.CarpResourcePaths)
	if err != nil {
		return nil, fmt.Errorf("failed to static resource matcher init during carp server start: %w", err)
	}

	session.InitCleanJob(ctx, cfg.JwtSessionCleanInterval)

	router := http.NewServeMux()

	proxyHandler, err := proxy.CreateProxyHandler(headers, cfg)

	casHandler := casfilter.Middleware(casBrowserClient, casRestClient, proxyHandler)

	throttlingHandler := throttling.NewThrottlingHandler(ctx, cfg, casHandler)

	bcLogoutHandler := session.Middleware(throttlingHandler, cfg, casBrowserClient)

	logHandler := internal.Middleware(bcLogoutHandler, "logging")

	appContextPathWithTrailingSlash, err := url.JoinPath(cfg.AppContextPath + "/")
	if err != nil {
		return nil, fmt.Errorf("failed to create app-context-path %s/: %w", cfg.AppContextPath, err)
	}

	router.Handle(appContextPathWithTrailingSlash, logHandler)

	log.Debugf("starting server on port %d", cfg.Port)

	return &http.Server{
		Addr:    ":" + strconv.Itoa(cfg.Port),
		Handler: router,
	}, nil
}

func NewCasClients(cfg config.Configuration) (*cas.Client, *cas.RestClient, error) {
	casUrl, err := url.Parse(cfg.CasUrl)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to parse cas url: %s: %w", cfg.CasUrl, err)
	}

	// CAS needs something like https://fqdn/sonar to register a dogu as proper CAS client dogu.
	sonarUrlWithContext, err := url.JoinPath(cfg.ServiceUrl, cfg.AppContextPath)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to join sonarqube context path for CAS clienting: %s: %w", cfg.CasUrl, err)
	}

	serviceUrl, err := url.Parse(sonarUrlWithContext)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to parse service url: %s: %w", sonarUrlWithContext, err)
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

	browserClient := cas.NewClient(&cas.Options{
		URL:             serviceUrl,
		Client:          httpClient,
		URLScheme:       urlScheme,
		IsLogoutRequest: isAlwaysDenyBackChannelLogoutRequest(),
	})
	restClient := cas.NewRestClient(&cas.RestOptions{
		ServiceURL:                         serviceUrl,
		Client:                             httpClient,
		URLScheme:                          urlScheme,
		CasURL:                             casUrl,
		ForwardUnauthenticatedRESTRequests: true,
	})
	return browserClient, restClient, nil
}

// isAlwaysDenyBackChannelLogoutRequest returns always false to circumvent go-cas' buggy backchannel logout request
// detection. Instead sonarcarp implements its own detection in session.Middleware.
func isAlwaysDenyBackChannelLogoutRequest() func(r *http.Request) bool {
	return func(r *http.Request) bool {
		return false
	}
}

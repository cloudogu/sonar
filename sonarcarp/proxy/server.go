package proxy

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"net/url"
	"path"
	"strconv"

	"github.com/cloudogu/sonar/sonarcarp/internal"
	carplog "github.com/cloudogu/sonar/sonarcarp/logging"
	"github.com/cloudogu/sonar/sonarcarp/session"
	"github.com/cloudogu/sonar/sonarcarp/throttling"
	"github.com/op/go-logging"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/config"
)

var log = logging.MustGetLogger("proxy")

func NewServer(ctx context.Context, configuration config.Configuration) (*http.Server, error) {
	casClient, err := NewCasClientFactory(configuration)
	if err != nil {
		return nil, fmt.Errorf("failed to create CAS client during carp server start: %w", err)
	}

	headers := authorizationHeaders{
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

	pHandler, err := createProxyHandler(
		headers,
		casClient,
		configuration,
	)

	throttlingHandler := throttling.NewThrottlingHandler(ctx, configuration, pHandler)

	bcLogoutHandler := session.Middleware(throttlingHandler, configuration)

	logHandler := carplog.Middleware(bcLogoutHandler, "throttling")

	router.Handle("/sonar/", logHandler)

	log.Debugf("starting server on port %d", configuration.Port)

	return &http.Server{
		Addr:    ":" + strconv.Itoa(configuration.Port),
		Handler: router,
	}, nil
}

func NewCasClientFactory(configuration config.Configuration) (*cas.Client, error) {
	casUrl, err := url.Parse(configuration.CasUrl)
	if err != nil {
		return nil, fmt.Errorf("failed to parse cas url: %s: %w", configuration.CasUrl, err)
	}

	serviceUrl, err := url.Parse(configuration.ServiceUrl)
	if err != nil {
		return nil, fmt.Errorf("failed to parse service url: %s: %w", configuration.ServiceUrl, err)
	}

	urlScheme := cas.NewDefaultURLScheme(casUrl)
	urlScheme.ServiceValidatePath = path.Join("p3", "serviceValidate")

	httpClient := &http.Client{}
	if configuration.SkipSSLVerification {
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

func isAlwaysDenyBackChannelLogoutRequest() func(r *http.Request) bool {
	return func(r *http.Request) bool {
		return false
	}
}

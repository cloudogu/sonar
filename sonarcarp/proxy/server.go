package proxy

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
	"github.com/op/go-logging"
)

var log = logging.MustGetLogger("sonarcarp")

func NewServer(ctx context.Context, configuration config.Configuration) (*http.Server, error) {
	staticResourceHandler, err := createStaticFileHandler()
	if err != nil {
		return nil, fmt.Errorf("failed to create static handler: %w", err)
	}

	casClient, err := NewCasClientFactory(configuration)
	if err != nil {
		return nil, fmt.Errorf("failed to create CAS client: %w", err)
	}

	headers := authorizationHeaders{
		Principal: configuration.PrincipalHeader,
		Role:      configuration.RoleHeader,
		Mail:      configuration.MailHeader,
		Name:      configuration.NameHeader,
	}

	router := http.NewServeMux()

	pHandler, err := createProxyHandler(
		configuration.ServiceUrl,
		headers,
		casClient,
		configuration.LogoutPath,
		configuration.LogoutRedirectPath,
	)

	throttlingHandler := NewThrottlingHandler(ctx, configuration, pHandler)

	router.Handle("/", throttlingHandler)

	if len(configuration.CarpResourcePath) != 0 {
		router.Handle(configuration.CarpResourcePath, http.StripPrefix(configuration.CarpResourcePath, loggingMiddleware(staticResourceHandler)))
	}

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
		IsLogoutRequest: isBackChannelLogoutRequest(),
	}), nil
}

func isBackChannelLogoutRequest() func(r *http.Request) bool {
	return func(r *http.Request) bool {
		return r.Method == "POST" && (r.URL.Path == "/sonar/" || r.URL.Path == "/sonar")
	}
}

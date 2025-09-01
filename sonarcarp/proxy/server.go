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

var log = logging.MustGetLogger("proxy")

func NewServer(ctx context.Context, configuration config.Configuration) (*http.Server, error) {
	//staticFileHandler, err := createStaticFileHandler()
	//if err != nil {
	//	return nil, fmt.Errorf("failed to create static handler: %w", err)
	//}

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
		headers,
		casClient,
		configuration,
	)

	loggedPHandler := loggingMiddleware(pHandler, "proxy")

	for _, alwaysAuthorizedRoutePattern := range configuration.CarpResourcePaths {
		log.Infof("Registering as static resource path: %s", alwaysAuthorizedRoutePattern)
		router.Handle("GET "+alwaysAuthorizedRoutePattern, http.StripPrefix("/sonar", loggingMiddleware(loggedPHandler, "staticProxyHandler")))
	}

	throttlingHandler := NewThrottlingHandler(ctx, configuration, loggedPHandler)

	router.Handle("/sonar/", throttlingHandler)

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

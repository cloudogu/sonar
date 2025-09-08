package proxy

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"strconv"

	"github.com/op/go-logging"

	"github.com/cloudogu/go-cas"
	"github.com/cloudogu/sonar/sonarcarp/config"
	carplog "github.com/cloudogu/sonar/sonarcarp/logging"
)

var log = logging.MustGetLogger("proxy")
var staticResourceMatchers []*regexp.Regexp

func NewServer(ctx context.Context, configuration config.Configuration) (*http.Server, error) {
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

	staticResourceMatchers, err = createStaticResourceMatchers(configuration.CarpResourcePaths)
	if err != nil {
		return nil, fmt.Errorf("failed to create static resource matchers: %w", err)
	}

	router := http.NewServeMux()

	pHandler, err := createProxyHandler(
		headers,
		casClient,
		configuration,
	)

	loggedPHandler := carplog.Middleware(pHandler, "proxy")

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

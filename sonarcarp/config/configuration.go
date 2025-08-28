package config

import (
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

const defaultFileName = "carp.yml"

type Configuration struct {
	BaseUrl                            string `yaml:"base-url"`
	CasUrl                             string `yaml:"cas-url"`
	ServiceUrl                         string `yaml:"service-url"`
	SkipSSLVerification                bool   `yaml:"skip-ssl-verification"`
	Port                               int    `yaml:"port"`
	PrincipalHeader                    string `yaml:"principal-header"`
	RoleHeader                         string `yaml:"role-header"`
	MailHeader                         string `yaml:"mail-header"`
	NameHeader                         string `yaml:"name-header"`
	CesAdminGroup                      string `yaml:"ces-admin-group"`
	SonarAdminGroup                    string `yaml:"sonar-admin-group"`
	LogoutRedirectPath                 string `yaml:"logout-redirect-path"`
	LogoutPath                         string `yaml:"logout-path"`
	ForwardUnauthenticatedRESTRequests bool   `yaml:"forward-unauthenticated-rest-requests"`
	LoggingFormat                      string `yaml:"log-format"`
	LogLevel                           string `yaml:"log-level"`
	ApplicationExecCommand             string `yaml:"application-exec-command"`
	CarpResourcePath                   string `yaml:"carp-resource-path"`
	LimiterTokenRate                   int    `yaml:"limiter-token-rate"`
	LimiterBurstSize                   int    `yaml:"limiter-burst-size"`
	LimiterCleanInterval               int    `yaml:"limiter-clean-interval"`
}

func InitializeAndReadConfiguration() (Configuration, error) {
	configuration, err := readConfiguration()
	if err != nil {
		return Configuration{}, fmt.Errorf("could not read configuration: %w", err)
	}

	err = initLogger(configuration)
	if err != nil {
		return Configuration{}, fmt.Errorf("could not configure logger: %w", err)
	}

	return configuration, nil
}

func readConfiguration() (Configuration, error) {
	confPath := defaultFileName

	// overwrite file with the first non-switch argument (probably avoiding go test args)
	if len(os.Args) > 1 {
		for _, arg := range os.Args[1:] {
			if strings.HasPrefix(arg, "-") {
				continue
			}

			if !isYamlFile(arg) {
				log.Warningf("Provided config file %s is no yaml file, try to use default file %s", arg, defaultFileName)
				break
			}

			confPath = arg
		}
	}

	data, err := os.ReadFile(confPath)
	if err != nil {
		return Configuration{}, fmt.Errorf("failed to read file from path %s: %w", confPath, err)
	}

	var config Configuration

	err = yaml.Unmarshal(data, &config)
	if err != nil {
		return Configuration{}, fmt.Errorf("failed to unmarshal file to configuration: %w", err)
	}

	return config, nil
}

func isYamlFile(fileName string) bool {
	return strings.HasSuffix(fileName, ".yaml") || strings.HasSuffix(fileName, ".yml")
}

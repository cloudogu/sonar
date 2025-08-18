package config

import (
	"fmt"
	"github.com/op/go-logging"
	"os"
	"slices"
)

func initLogger(configuration Configuration) error {
	backend := logging.NewLogBackend(os.Stderr, "", 0)

	var format = logging.MustStringFormatter(configuration.LoggingFormat)
	formatter := logging.NewBackendFormatter(backend, format)

	level, err := convertLogLevel(configuration.LogLevel)
	if err != nil {
		return fmt.Errorf("unable to convert level: %s, to loglevel: %w", configuration.LogLevel, err)
	}

	backendLeveled := logging.AddModuleLevel(formatter)
	backendLeveled.SetLevel(level, "")

	logging.SetBackend(backendLeveled)

	log.Infof("Initialized logger with log-level: %s", level)

	return nil
}

func convertLogLevel(logLevel string) (logging.Level, error) {
	if !slices.Contains([]string{"DEBUG", "WARN", "INFO", "ERROR"}, logLevel) {
		return 0, fmt.Errorf("the log level '%s' was not found, only WARN, DEBUG, INFO and ERROR are allowed", logLevel)
	}
	switch logLevel {
	case "WARN":
		return logging.WARNING, nil
	default:
		return logging.LogLevel(logLevel)
	}
}

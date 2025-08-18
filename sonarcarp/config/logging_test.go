package config

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestPreparesLoggerSuccessfully(t *testing.T) {
	err := initLogger(Configuration{
		LoggingFormat: "%{time:2006-01-02 15:04:05.000-0700} %{level:.4s} [%{module}:%{shortfile}] %{message}",
		LogLevel:      "DEBUG",
	})
	assert.Nil(t, err)
}
func TestCanHandleWarn(t *testing.T) {
	err := initLogger(Configuration{
		LoggingFormat: "%{time:2006-01-02 15:04:05.000-0700} %{level:.4s} [%{module}:%{shortfile}] %{message}",
		LogLevel:      "WARN",
	})
	assert.Nil(t, err)
}

func TestFailOnInvalidLogLevel(t *testing.T) {
	err := initLogger(Configuration{
		LoggingFormat: "%{time:2006-01-02 15:04:05.000-0700} %{level:.4s} [%{module}:%{shortfile}] %{message}",
		LogLevel:      "WARNING",
	})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "WARNING")
}

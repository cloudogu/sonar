package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const templateConfig = `
cas-url: https://192.168.56.2/cas
service-url: http://localhost:9000/
target-url: http://localhost:3000/sonar/login
logout-method: GET
logout-path-frontchannel-endpoint: /sonar/sessions/logout
logout-path-backchannel-endpoint: /api/authentication/logout
port: 8080
principal-header: X-Forwarded-Login
role-header: X-Forwarded-Groups
mail-header: X-Forwarded-Email
name-header: X-Forwarded-Name
ces-admin-group: cesAdmin
sonar-admin-group: sonar-administrators
log-format: "%{time:2006-01-02 15:04:05.000-0700} %{level:.4s} [%{module}:%{shortfile}] %{message}"
application-exec-command: "exit 0"
carp-resource-paths:
   - /sonar/js/
`

const invalidType = templateConfig + `
skip-ssl-verification: invalidBoolean
log-level: DEBUG
`

const invalidLogLevel = templateConfig + `
skip-ssl-verification: true
log-level: Invalid
`

const validConfig = templateConfig + `
skip-ssl-verification: true
log-level: DEBUG
`

func createTemporaryFile(t *testing.T, content string) (string, func()) {
	file, err := os.CreateTemp("", "carp.*.yml")
	require.NoError(t, err, "failed to create temporary config file")

	cleanUp := func() {
		_ = os.Remove(file.Name())
	}

	_, err = file.WriteString(content)
	if err != nil {
		cleanUp()
	}

	require.NoError(t, err, "failed to write temporary config file")

	return file.Name(), cleanUp
}

func TestInitializeAndReadConfiguration(t *testing.T) {
	t.Run("Read config", func(t *testing.T) {
		cfgFile, cleanUp := createTemporaryFile(t, validConfig)
		defer cleanUp()

		os.Args = []string{"", cfgFile}
		config, err := InitializeAndReadConfiguration()

		assert.NoError(t, err)
		checkConfig(t, config)
	})

	t.Run("Config file does not exist", func(t *testing.T) {
		_, err := InitializeAndReadConfiguration()
		assert.Error(t, err)
	})

	t.Run("Invalid Yaml File", func(t *testing.T) {
		cfgFile, cleanUp := createTemporaryFile(t, invalidType)
		defer cleanUp()

		os.Args = []string{"", cfgFile}
		_, err := InitializeAndReadConfiguration()

		assert.Error(t, err)
	})

	t.Run("Invalid Loglevel in config", func(t *testing.T) {
		cfgFile, cleanUp := createTemporaryFile(t, invalidLogLevel)
		defer cleanUp()

		os.Args = []string{"", cfgFile}
		_, err := InitializeAndReadConfiguration()

		assert.Error(t, err)
	})
}

func checkConfig(t *testing.T, config Configuration) {
	t.Helper()
	assert.Equal(t, "https://192.168.56.2/cas", config.CasUrl)
	assert.Equal(t, "http://localhost:9000/", config.ServiceUrl)
	assert.Equal(t, "/sonar/sessions/logout", config.LogoutPathFrontchannelEndpoint)
	assert.Equal(t, "/api/authentication/logout", config.LogoutPathBackchannelEndpoint)
	assert.Equal(t, true, config.SkipSSLVerification)
	assert.Equal(t, 8080, config.Port)
	assert.Equal(t, "X-Forwarded-Login", config.PrincipalHeader)
	assert.Equal(t, "X-Forwarded-Groups", config.RoleHeader)
	assert.Equal(t, "X-Forwarded-Email", config.MailHeader)
	assert.Equal(t, "X-Forwarded-Name", config.NameHeader)
	assert.Equal(t, "%{time:2006-01-02 15:04:05.000-0700} %{level:.4s} [%{module}:%{shortfile}] %{message}", config.LoggingFormat)
	assert.Equal(t, "DEBUG", config.LogLevel)
	assert.Equal(t, "exit 0", config.ApplicationExecCommand)
	assert.Equal(t, []string{"/sonar/js/"}, config.CarpResourcePaths)
}

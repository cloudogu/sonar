package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const templateConfig = `
base-url: https://localhost:8080
cas-url: https://192.168.56.2/cas
service-url: https://localhost:8080/sonar/login
target-url: http://localhost:3000/sonar/login
logout-method: GET
logout-path: \/sonar\/(cas\/)?logout
port: 8080
principal-header: X-WEBAUTH-USER
role-header: X-WEBAUTH-ROLE
mail-header: X-WEBAUTH-EMAIL
name-header: X-WEBAUTH-NAME
create-user-endpoint: http://localhost:3000/sonar/api/admin/users
create-group-endpoint: http://localhost:3000/sonar/api/teams
get-user-groups-endpoint: http://localhost:3000/sonar/api/users/%v/teams
get-user-endpoint: http://localhost:3000/sonar/api/users/lookup?loginOrEmail=%s
remove-user-from-group-endpoint: http://localhost:3000/sonar/api/teams/%v/members/%v
add-user-to-group-endpoint: http://localhost:3000/sonar/api/teams/%v/members
search-team-by-name-endpoint: http://localhost:3000/sonar/api/teams/search?name=%s
set-organization-role-endpoint: http://localhost:3000/sonar/api/orgs/1/users/%v
ces-admin-group: cesAdmin
sonar-admin-group: admin
sonar-writer-group: writer
sonar-reader-group: reader
log-format: "%{time:2006-01-02 15:04:05.000-0700} %{level:.4s} [%{module}:%{shortfile}] %{message}"
application-exec-command: "exit 0"
carp-resource-path: /sonar/carp-static
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
	assert.Equal(t, "https://localhost:8080", config.BaseUrl)
	assert.Equal(t, "https://192.168.56.2/cas", config.CasUrl)
	assert.Equal(t, "https://localhost:8080/sonar/login", config.ServiceUrl)
	assert.Equal(t, "\\/sonar\\/(cas\\/)?logout", config.LogoutPath)
	assert.Equal(t, true, config.SkipSSLVerification)
	assert.Equal(t, 8080, config.Port)
	assert.Equal(t, "X-WEBAUTH-USER", config.PrincipalHeader)
	assert.Equal(t, "X-WEBAUTH-ROLE", config.RoleHeader)
	assert.Equal(t, "X-WEBAUTH-EMAIL", config.MailHeader)
	assert.Equal(t, "X-WEBAUTH-NAME", config.NameHeader)
	assert.Equal(t, "%{time:2006-01-02 15:04:05.000-0700} %{level:.4s} [%{module}:%{shortfile}] %{message}", config.LoggingFormat)
	assert.Equal(t, "DEBUG", config.LogLevel)
	assert.Equal(t, "exit 0", config.ApplicationExecCommand)
	assert.Equal(t, "/sonar/carp-static", config.CarpResourcePath)
}

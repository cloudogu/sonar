# Easier scanning with Sonar-scanner-cli

Due to common certificate errors, it is not that easy to use the sonar scanner in a local system with self-signed certificates.

To avoid installing a whole stack of SCM Manager, Jenkins, etc., it is easier to modify a Sonar scanner with your own certificate:

<!-- markdown-link-check-disable-next-line -->
1. Generate a SonarQube token, e.g., at https://example.invalid/sonar/account/security.
   - In this example: `sqa_3ffb7e36dee85c27ab1b3cca58e0dea400068f70`
2. Select the codebase to be scanned
3. Copy the certificate to a file and store it in the codebase's file system
   - CES-VM: `etcdctl get /config/_global/certificate/server.crt > /vagrant/ces.pem`
4. Copy the certificate to the codebase directory
5. From the codebase directory (`$PWD -> /usr/src/`)
   1. Start Sonar scanner,
   2. Import the certificate, and
   3. Scan
   4. Scan a second time for good measure, because SonarQube is weird and hates first scans

```shell
docker run \                         
    --rm -u 0 \
    -e SONAR_HOST_URL="https://example.invalid/sonar"  \
    -e SONAR_TOKEN="sqa_3ffb7e36dee85c27ab1b3cca58e0dea400068f70" \
    -v "${PWD}:/usr/src" -it --entrypoint sh \
    sonarsource/sonar-scanner-cli

# You will be taken to a shell. Here we continue:
cd /usr/lib/jvm/java-17-openjdk/lib/security
keytool -import -trustcacerts -noprompt -alias sonarqube -file /usr/src/ces.pem -keystore cacerts -storepass changeit
cd -
sonar-scanner
exit # This leaves the container, which is now being deleted. Everything must be repeated for the next scan
```

## Minimal example of a codebase

To find out if and how SonarQube and Sonarcarp work, two or three files are sufficient:

- `go.mod`
```shell
mkdir test
cd test
go mod init test
```
- `main.go`
```go
package main

import (
	"fmt"
	"path/filepath"
)

func main() {
	a, err := filepath.Abs("asdf") // error here
	fmt.Println("hello world", a)
}
```
- sonar-project.properties
```
sonar.projectKey=test
sonar.sources=.
sonar.exclusions=**/*_test.go,**/vendor/**,**/target/**,**/mocks/**,**/*_mock.go,resources/test/**/index.html,**/mock_**,**/build/make/**
sonar.tests=.
sonar.test.inclusions=**/*_test.go
sonar.test.exclusions=**/vendor/**,**/target/**
```

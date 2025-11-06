# Einfacher mit Sonar-scanner-cli scannen

Wegen üblicher Zertifikatsfehler ist es nicht so ganz einfach, in einem lokalen System mit selbst-signierten Zertifikaten den sonar-scanner zu verwenden.

## SonarQube-Scan ganz ohne Pipelinetools

Um weiterhin nicht einen ganzen Stack von SCM-Manager, Jenkins usw. zu installieren, lässt sich leichter Abhilfe schaffen, wenn man einen Sonar-Scanner mit einem eigenen Zertifikat modifiziert:

1. SonarQube-Token erzeugen, z. B. unter https://example.invalid/sonar/account/security
   - in diesem Beispiel: `sqa_3ffb7e36dee85c27ab1b3cca58e0dea400068f70`
2. Codebase auswählen, die gescannt werden soll
   - siehe unten für ein Minimalbeispiel:
3. Zertifikat in eine Datei kopieren und im Dateisystem der Codebase hinterlegen
   - CES-VM: `etcdctl get /config/_global/certificate/server.crt > /vagrant/ces.pem`
4. Zertifikat in das Verzeichnis der Codebase kopieren
5. Aus dem Verzeichnis der Codebase heraus (`$PWD -> /usr/src/`) 
   1. Sonar-scanner starten, 
   2. Zertifikat importieren und 
   3. scannen
   4. scannen, zur Sicherheit ein zweites Mal, denn SonarQube ist seltsam und hasst erste Scans

```shell
docker run \                         
    --rm -u 0 \
    -e SONAR_HOST_URL="https://example.invalid/sonar"  \
    -e SONAR_TOKEN="sqa_3ffb7e36dee85c27ab1b3cca58e0dea400068f70" \
    -v "${PWD}:/usr/src" -it --entrypoint sh \
    sonarsource/sonar-scanner-cli

# man landet in einer shell. Hierin geht es weiter:
cd /usr/lib/jvm/java-17-openjdk/lib/security
keytool -import -trustcacerts -noprompt -alias sonarqube -file /usr/src/ces.pem -keystore cacerts -storepass changeit
cd -
sonar-scanner
exit # dies verlässt den Container, der nun gelöscht wird. Für den nächsten Scan muss alles wiederholt werden
```

## Minimalbeispiel einer Codebase

Um herauszufinden, ob und wie SonarQube samt Sonarcarp funktioniert, reichen schon zwei bis drei Dateien:

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

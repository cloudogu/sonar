# Das SonarQube-Dogu entwickeln

SonarQube wird innerhalb einer laufenden CES-Instanz gebaut, indem in dieses Repository gewechselt wird. Dann muss `cesapp` aufgerufen werden, um das Dogu zu installieren/upgraden und zu starten:

```bash
cd /your/workspace/sonar
cesapp build .
cesapp start sonar
```

## Einbinden und Testen des Sonar-CAS-Plugins innerhalb des Dogus

Es gibt zwei Alternativen zum Testen von Entwicklungsversionen des [Sonar CAS Plugin](https://github.com/cloudogu/sonar-cas-plugin/) (die Anleitung zum Kompilieren finden Sie dort):

1. Die Plugin-Version in einem bereits laufenden SonarQube ersetzen
   - `rm /var/lib/ces/sonar/volumes/extensions/plugins/sonar-cas-plugin-2.0.1.jar`
   - `cp your-sonar-cas-plugin.jar /var/lib/ces/sonar/volumes/extensions/plugins/`
   - `sudo docker restart sonar`
1. Das Dockerfile ändern und ein neues Image mit der lokalen Plugin-Version erstellen
   - die Zeilen auskommentieren, die sich auf das Sonar-CAS-Plugin beziehen
   - eine neue Zeile für `COPY` für das Plugin hinzufügen, etwa so:
      - `COPY --chown=1000:1000 sonar-cas-plugin-3.0.0-SNAPSHOT.jar ${SONARQUBE_HOME}/sonar-cas-plugin-3.0.0-SNAPSHOT.jar`

## Shell-Tests mit BATS

Bash-Tests können im Verzeichnis `unitTests` erstellt und geändert werden. Das make-Target `unit-test-shell` unterstützt hierbei mit einer verallgemeinerten Bash-Testumgebung.

```bash
make unit-test-shell
```

BATS wurde so konfiguriert, dass es JUnit kompatible Testreports in `target/shell_test_reports/` hinterlässt.

Um testbare Shell-Skripte zu schreiben, sollten diese Aspekte beachtet werden:

### Globale Umgebungsvariable `STARTUP_DIR`

Die globale Umgebungsvariable `STARTUP_DIR` zeigt auf das Verzeichnis, in dem sich die Produktionsskripte (aka: Skripte-unter-Tests) befinden. Innerhalb des dogu-Containers ist dies normalerweise `/`. Aber während des Testens ist es einfacher, es aus Gründen der Berechtigung irgendwo anders abzulegen.

Ein zweiter Grund ist, dass die Skripte-unter-Tests andere Skripte quellen lassen. Absolute Pfade machen das Testen ziemlich schwer. Neue Skripte müssen wie folgt gesourcet werden, damit die Tests reibungslos ablaufen können:

```bash
source "${STARTUP_DIR}"/util.sh
```

Im obigen Beispiel dient der Kommentar zur Deaktivierung von Shellcheck. Da `STARTUP_DIR` im `Dockerfile` verdrahtet ist, wird es als globale Umgebungsvariable betrachtet, die niemals ungesetzt gefunden werden wird (was schnell zu Fehlern führen würde).

Wenn Skripte derzeit auf statische Weise gesourcet werden (d. h. ohne dynamische Variable im Pfad), macht das Shell-Tests unmöglich (es sei denn, ein besserer Weg wird gefunden, den Test-Container zu konstruieren).

Es ist eher unüblich, ein _Scripts-under-test_ wie `startup.sh` ganz alleine laufen zu lassen. Effektive Unit-Tests entwickeln sich sehr wahrscheinlich zu einem Alptraum, wenn keine ordentliche Skriptstruktur vorhanden ist. Da diese Skripte sich gegenseitig sourcen  _und_ Code ausführen, muss **alles** vorher eingerichtet werden: globale Variablen, Mocks von jedem einzelnen Binary, das aufgerufen wird... und so weiter. Am Ende würden die Tests eher auf einer End-to-End-Testebene als auf einer Unit-Test-Ebene angesiedelt sein.

Die gute Nachricht ist, dass das Testen einzelner Funktionen mit diesen kleinen Teilen möglich ist:

1. Sourcing execution guards verwenden
1. Binaries und Logikcode nur innerhalb von Funktionen ausführen
1. Sourcen mit (dynamischen, aber festgelegten) Umgebungsvariablen

#### Sourcing execution guards verwenden

Das Sourcen mit _sourcing execution guards._ kann wie folgt ermöglicht werden:

```bash
# yourscript.sh
function runTheThing() {
    echo "hello world"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  runTheThing
fi
```

Die folgende `if`-Bedingung wird ausgeführt, wenn das Skript durch einen Aufruf über die Shell ausgeführt wird, aber nicht, wenn es über eine Quelle aufgerufen wird:

```bash
$ ./yourscript.sh
hallo Welt
$ source yourscript.sh
$ runTheThing
Hallo Welt
$
```

_Execution guards_ funktionieren auch mit Parametern:

```bash
# yourscript.sh
function runTheThing() {
    echo "${1} ${2}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  runTheThingWithParameters "$@"
fi
```

Es muss die korrekte Argumentübergabe mit `"$@"` beachtet werden, die auch solche Argumente zulässt, die Leerzeichen und dergleichen enthalten.

```bash
$ ./yourscript.sh hello world
hello world
$ source yourscript.sh
$ runTheThing hello bash
hello bash
$
```

#### Binärdateien und Logikcode nur innerhalb von Funktionen ausführen

Umgebungsvariablen und Konstanten sind in Ordnung, aber sobald Logik außerhalb einer Funktion läuft, wird sie beim Sourcen von Skripten ausgeführt.

#### Source mit (dynamischen, aber fixierten) Umgebungsvariablen

Shellcheck makert solch ein Vorgehen grundsätzlich als Fehler an. Solange der Testcontainer keine entsprechenden Skriptpfade zulässt, gibt es allerdings kaum eine Möglichkeit, dies zu umgehen:

```bash
sourcingExitCode=0
# shellcheck disable=SC1090
source "${STARTUP_DIR}"/util.sh || sourcingExitCode=$?
if [[ ${sourcingExitCode} -ne 0 ]]; then
  echo "ERROR: An error occurred while sourcing /util.sh."
fi
```

Es muss sichergestellt werden, dass die Variablen in der Produktions- (z. B. `Dockerfile`) und Testumgebung richtig gesetzt sind (hierzu eignen sich Umgebungsvariablen im Test).

## SonarQube-Dogu testen

Wegen Kommunikationsprobleme durch selbst-signierte SSL-Zertifikate in einer Entwicklungs-CES-Instanz bietet es sich an, den SonarScanner per Jenkins in der gleichen Instanz zu betreiben. Folgendes Vorgehen hat sich bewährt:

1. SCM-Manager und Jenkins im CES installieren
   - `cesapp install official/jenkins; cesapp install official/scm; cesapp start scm; cesapp start jenkins`
2. SCMM:
   - Spring Petclinic im SCM-Manager durch SCMM-Repo-Import in ein neues Repository einspielen 
   - Import: https://github.com/cloudogu/spring-petclinic/
   - Admin-Credentials reichen für diesen Test aus
3. SonarQube
   1. SonarQube-Token anlegen
      1. Als Admin auf die [Security-Seite navigieren](https://192.168.56.2/sonar/account/security) <!-- markdown-link-check-disable-line -->
      2. Token generieren
         - Name: `admin_token`
         - Type: `Global Analysis Token`
         - Expires in: `30 Days`
      3. generierten Token kopieren
   2. Webhook anlegen
      1. Als Admin auf die [globale Webhooks-Seite navigieren](https://192.168.56.2/sonar/admin/webhooks) <!-- markdown-link-check-disable-line -->
      2. einen neuen Webhook über den `[ Create ]`-Button anlegen
         - Name: `ces`
         - URL: `https://192.168.56.2/jenkins/sonarqube-webhook` <!-- markdown-link-check-disable-line -->
         - Secret: leer lassen
4. Jenkins
   1. ggf. Sonar-Scanner anlegen
      - zu [Dashboard/Jenkins verwalten/Tools](https://192.168.56.2/jenkins/manage/configureTools/) navigieren <!-- markdown-link-check-disable-line -->
      - Im Abschnitt "SonarQube Scanner Installationen" einen Eintrag über Maven Central anlegen
      - name: `sonar-scanner` 
      - Version: `4.8.1` (maximal [Java 11](https://docs.sonarsource.com/sonarqube/9.9/analyzing-source-code/scanners/sonarscanner/))
   2. ggf. SonarServer konfigurieren
      - zu [Dashboard/Jenkins verwalten/System](https://192.168.56.2/jenkins/manage/configure) navigieren <!-- markdown-link-check-disable-line -->
      - Im Abschnitt "SonarQube servers" folgendes konfigurieren
        - Environment variables: ja/check
        - Name: `sonar`
        - Server URL: `http://sonar:9000/sonar`
        - Server authentication token: `add` drücken
          - Credential fom Typ "Secret Text" mit dem im SonarQube generierten Token anlegen
        - Hier ** darf kein Secret** für den **Webhook** hinterlegt werden
   2. Credentials für SCMM und SonarQube im [Jenkins Credential Manager](https://192.168.56.2/jenkins/manage/credentials/store/system/domain/_/newCredentials) einfügen <!-- markdown-link-check-disable-line -->
      - Admin-Credentials unter der ID `scmCredentials` ablegen
        - SCMM und SonarQube teilen sich Admin-Credentials (SCMM in der Build-Konfiguration, SonarQube im Jenkinsfile)
      - für SonarQube auf Credentialtyp achten!
         - `Username/Password` für Basic Authentication
   2. Build-Job anlegen
      1. Element anlegen -> `Multibranch Pipeline` auswählen -> Job konfigurieren
         - Branch Sources/Add source: "SCM-Manager (git, hg)" auswählen 
         - Server URL: https://192.168.56.2/scm/ <!-- markdown-link-check-disable-line -->
         - Credentials für SCM-Manager: oben konfiguriertes Credential `scmCredentials` auswählen
      2. Job speichern
         - das Jenkinsfile wird automatisch gefunden
      3. ggf. überzählige/nicht funktionierende Jobs abbrechen
      4. master-Branch hinsichtlich geänderter Credentials oder unerwünschter Job-Stages anpassen und bauen
         - wichtig ist eine alte Version (ces-build-lib@1.35.1) der `ces-build-lib`, neuere Versionen führen zu Authentifizierungsfehlern
         - ein Austausch gegen eine neuere Build-lib ist im Rahmen von Smoketests von SonarQube nicht maßgeblich

### Testen des SonarQube Community Plugin

1. In SonarQube: das Community Branch Plugin einrichten
   1. Als CES-Shell-Administrator: das [SonarQube version appropriate community plugin](https://github.com/mc1arke/sonarqube-community-branch-plugin?tab=readme-ov-file#compatibility) als JAR herunterladen und es nach   `/var/lib/ces/sonar/volumes/extensions/plugins/` verschieben
   2. SonarQube neustarten
2. Im SCM-Manager: die Editor - und Review-Plugins installieren
   - damit ist die Bearbeitung von Quelldateien auch ohne `git clone ... ; git commit ...` möglich  
3. spring-petclinic/ `master`-Branch bearbeiten
   - im SCM-Manager eine `sonar-project.properties` anlegen (sofern noch nicht vorhanden)
      - Beispiel siehe unten
      - dies sorgt dafür, dass SonarQube die gebauten `.class`-Files findet
   - im SCM-Manager das `Jenkinsfile` anreichern, dass `stage("build")` und `stage("integration test")` zusätzlich vorhanden sind
     - Beispiel siehe unten
     - dies sort dafür, dass SonarQube auch PR-Branches scannt und Jenkins über den Status informiert
4. In SonarQube den Main-Branch umdeklarieren (nur wenn nötig)
   1. zu [Projekte](https://192.168.56.2/sonar/admin/projects_management)  navigieren <!-- markdown-link-check-disable-line -->
   2. nur bei einem erfolgten Scan eines falschen Branches nötig
   3. Als `main` markiertes Projekt in den gewünschten Branch umbenennen, z. B. `master`
   4. die übrigen Projekte löschen
5. PR-Branch-Erkennung testen
   1. im SCM-Manager einen neuen Branch auf `master`-Basis anlegen
   2. eine beliebige Datei minimal ändern und commiten (um PR zu ermöglichen)
   3. PR von neuem Branch auf `master` anlegen
6. Nach PR-Anlage SonarQube und Jenkins-Job auf Scan-Ergebnis prüfen

**sonar-project.properties**

```properties
sonar.projectKey=spring-petclinic

sonar.sources=./src/main/java
sonar.tests=./src/test/java
sonar.java.binaries=./target/classes

sonar.junit.reportPaths=./target/surefire-reports
sonar.coverage.jacoco.xmlReportPaths=./target/site/jacoco/jacoco.xml
```

**Jenkinsfile**

> Dies ist nur eine Vorlage!
> Siehe Kommentare, um nötige Anpassungen vorzunehmen

```groovy
#!groovy
@Library('github.com/cloudogu/ces-build-lib@2.2.1')
import com.cloudogu.ces.cesbuildlib.*

node {

    Git git = new Git(this, "admin")
    git.committerName = 'admin'
    git.committerEmail = 'admin@admin.de'
    projectName="spring-petclinic"
    branch = "${env.BRANCH_NAME}"
    Maven mvn = new MavenWrapper(this)

    String credentialsId = 'scmCredentials'

    catchError {
        // usual stages go here: Checkout, Build, Test, Integration Test
        stage("...") {}
        
        stage('SonarQube') {
            def scannerHome = tool name: 'sonar-scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
            env.JAVA_HOME="${tool 'OpenJDK-11'}"
            withSonarQubeEnv {
                gitWithCredentials("fetch --all", credentialsId)

                if (branch == "master") {
                    echo "This branch has been detected as the master branch."
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName}"
                } else if (branch == "develop") {
                    echo "This branch has been detected as the develop branch."
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${env.BRANCH_NAME} -Dsonar.branch.target=master  "
                } else if (env.CHANGE_TARGET) {
                    echo "This branch has been detected as a pull request."
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.pullrequest.key=${env.CHANGE_ID} -Dsonar.pullrequest.branch=${env.CHANGE_BRANCH} -Dsonar.pullrequest.base=develop    "
                } else {
                    echo "This branch has been detected as a feature branch."
                    sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${projectName} -Dsonar.projectName=${projectName} -Dsonar.branch.name=${env.BRANCH_NAME} -Dsonar.branch.target=develop"
                } // add more to your liking
            }

            timeout(time: 60, unit: 'SECONDS') { // Works best with Webhooks, otherwise it needs a sleep which may not work for the async SQ scan
                def qGate = waitForQualityGate()
                if (qGate.status != 'OK') {
                    unstable("Pipeline unstable due to SonarQube quality gate failure")
                }
            }
        }
    }

    junit allowEmptyResults: true, testResults: '**/target/failsafe-reports/TEST-*.xml,**/target/surefire-reports/TEST-*.xml'
}

void gitWithCredentials(String command, String credentialsId) {
    withCredentials([usernamePassword(credentialsId: credentialsId, usernameVariable: 'GIT_AUTH_USR', passwordVariable: 'GIT_AUTH_PSW')]) {
        sh(
                script: "git -c credential.helper=\"!f() { echo username='\$GIT_AUTH_USR'; echo password='\$GIT_AUTH_PSW'; }; f\" " + command,
                returnStdout: true
        )
    }
}
```
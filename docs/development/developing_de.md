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

1. SCM-Manager und Jenkins installieren
   - `cesapp install official/scm; cesapp install official/scm; cesapp start scm; cesapp start jenkins`
1. SCMM: Spring Petclinic im SCM-Manager durch SCMM-Repo-Import in ein neues Repository einspielen
1. SonarQube: ggf. lokale User oder API-Token erzeugen
1. Jenkins
   1. Credentials für SCMM und SonarQube im Jenkins Credential Manager einfügen
      - für SCMM z. B. unter der ID `scmCredentials`
      - für SonarQube auf Credentialtyp achten!
         - `Username/Password` für Basic Authentication
         - `Secret text` für SQ API Token
   1. Build-Job anlegen
      1. Element anlegen -> `SCM-Manager Namespace` auswählen -> Job konfigurieren
         - Repo: https://192.198.56.2/scm
         - Credentials: wie oben konfiguriert
      1. Job speichern
      1. ggf. überzählige/nicht funktionierende Jobs abbrechen
      1. master/main-Branch anpassen und bauen

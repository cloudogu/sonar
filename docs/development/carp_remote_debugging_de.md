# CARP-Remote-Debugging

Es ist möglich, sonarcarp während der Ausführung in einem bestehenden Ökosystem zu debuggen, um die Analyse bestimmter 
Verhaltensweisen zu erleichtern.

# Remote-Debugging aktivieren

Um das Remote-Debugging für sonarcarp zu aktivieren, müssen die `.env`-Datei anpassen, indem Sie die folgende Zeile hinzufügen:

```
DEBUG=true
```

Dadurch wird ein neues Sonar-Image erstellt, das [Delve](https://github.com/go-delve/delve/tree/master) enthält, und sonarcarp
mit `delve` gestartet, das auf eine Remote-Debugging-Sitzung auf Port `2345` wartet.

# Portweiterleitung für Debugging-Port

Um auf den Remote-Debugging-Port zugreifen zu können, müssen wir den Port noch weiterleiten, damit er für den Remote-Debugger zugänglich ist.

## CES-Multinode

Um sonarcarp in CES Multinode zu debuggen, müssen Sie lediglich eine Portweiterleitung für Port 2345 zum Sonar-Pod erstellen.
Die Portweiterleitung kann mit kubectl oder mit k9s erstellt werden.

```shell
kubectl port-forward sonar-6d7b47cd7b-pqprr 2345:2345
```

Der Remote-Debugger kann dann eine Verbindung zu `localhost:2345` herstellen.

## CES-VM

## CES-VM

Es erfordert etwas mehr Aufwand (im Wesentlichen zwei geänderte Dateien und eine deaktivierte Firewall), um Sonarcarp in einer CES-VM zu debuggen.

**`dogu.json`**
Fügen Sie die folgende Zeile `ExposedPort` zur Datei `dogu.json` hinzu, um den Port außerhalb der VM freizugeben.

**WARNUNG**
Achten Sie darauf, diese Zeile NICHT ZU COMMITTEN, da sie Dogu ohne Einschränkungen vollständig nach außen offenlegt.

```
  "ExposedPorts": [
    { "Type": "tcp", "Container": 2345, "Host": 2345 }
  ]
```

Fügen Sie dann die angepasste `dogu.json` zu Ihrer Registrierung hinzu

**`Dockerfile`**

Fügen Sie diese Zeilen in der letzten Phase zur `Dockerfile` hinzu, z. B. in der Nähe des Startbefehls `CMD`:

```dockerfile
# ...Rest von Dockerfile

ENV SERVICE_8080_TAGS="webapp" \
    SERVICE_8080_NAME="sonar"

CMD ["/startup.sh"]
```

Diese Zeilen konfigurieren die richtigen `services`-Schlüssel in der CES-Registrierung, sodass nginx eine korrekte Route
zu `/sonar` erstellt. Andernfalls würden die beiden freigegebenen Ports (Anwendung und Delve) wie `/sonar-8080` geroutet, 
was in keiner Weise funktioniert.

```shell
cd /vagrant/containers/sonar # oder wo auch immer sich Ihr Sonarqube-Repo befindet
cesapp build . && cesapp start sonar
```

Deaktivieren Sie dann die Firewall der VM, damit der Port tatsächlich verbunden werden kann.
```shell
sudo ufw disable
```

`cesapp` verarbeitet die erforderliche Umgebungsvariable `STAGE=debug` überhaupt nicht, aber die Variable wird benötigt, 
um dieses Image zu erstellen, damit `dlv` ausgeführt werden kann. Ersetzen wir das Dogu-Image durch eines, das den 
`dlv`-fähigen Build enthält, mit diesen beiden Aufrufen aus der CES-VM heraus:

```shell
make docker-build
cesapp recreate --start sonar
```

Wie oben für die Multinode-Installation beschrieben, wird dogu erst dann funktionsfähig, wenn Sie Ihren Debugger mit `dlv` verbinden. Richten Sie
Ihren Debugger auf die äußere VM-IP-Adresse an Port 2345 (z. B. `192.168.56.2:2345`)

**DIES MUSS UNBEDINGT VOR EINEM COMMIT AUFGERÄUMT WERDEN**

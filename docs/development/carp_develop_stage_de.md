# CARP Entwicklungsmodus

Folgende Schritte sind nötig, um den SonarCARP debuggen zu können.

## Konfiguration anpassen
`sonarcarp/carp.yaml` in anpassen.

## externes SonarQube im CES-CAS erlauben

Zum lokalen Testen einiger Dogus ist es notwendig, den CAS in den Entwicklungsmodus zu versetzen.
Das führt dazu, dass alle Applikationen sich über den CAS authentifizieren können, auch wenn sie dort nicht
konfiguriert sind.
Dafür muss die Stage des EcoSystems auf `development` gesetzt werden und das Dogu neu gestartet werden:

```
etcdctl set /config/_global/stage development
docker restart cas
```

## SonarQube starten
```
cd sonarcarp
export SONAR_CAS_LOCAL_IP=192.168.56.1
docker compose up -d && docker compose logs sonar -f
```

Hinweis: Falls sonar nicht startet, könnte es an den Permissions liegen. Dafür zum Beispiel einfach `sudo chown -R 1000:1000 ./sonar-home` ausführen.

## sonarcarp starten

Es muss eine Golang-Debugger-Configuration in der IDE existieren und gestartet werden.

## CAS-Login testen

1. Im Browser diese URL aufrufen: http://localhost:8080/sonar
   - bei Aufruferfolg zum CAS weitergeleitet werden, die unter diesem `carp.yaml`-Property konfiguriert wurde: `cas-url`
2. Im CAS anmelden
   - bei Anmeldeerfolg zum SonarQube weitergeleitet werden, die unter diesem `carp.yaml`-Property konfiguriert wurde: `http://localhost:9000/sonar/
cas`  


## CAS-Logout testen

Bei Misserfolg kann u. U. eine manuelle Eingabe der URL http://localhost:8080/sonar/sessions/logout helfen. Diese URL wird
in diesem `carp.yaml`-Property konfiguriert: `logout-path`

## Aufräumen

SonarQube wieder abreißen
```
docker compose stop && docker compose rm -f
```

Ggf. ist es nötig mit root-Rechten, diese Verzeichnisse zu löschen, da diese evtl. vom Container angelegt werden:

```sudo rm -rf \
   sonar-home/data/ \
   sonar-home/logs/ \
   sonar-home/temp/ \
   sonar-home/plugins
```
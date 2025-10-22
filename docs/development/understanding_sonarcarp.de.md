# Die Wirkweise von sonarcarp verstehen

## Allgemeine Workflows im Sonarcarp

### Log-in

Mit SonarQube 2025 musste wegen einer mangelhaften Unterstützung das Sonar-CAS-Plugin durch einen CAS Authentication
Reverse Proxy (CARP) abgelöst werden.

Beim Dogu-Start werden zunächst SonarQube-Startparameter in die CARP-Konfigurationsdatei gerendert. Sonarcarp führt mit diesem Befehl dann SonarQube aus, um mehrere Hauptprozesse im Container (und damit z. B. Container-Stopp-Probleme) zu vermeiden. 

Dieser Sonarcarp befindet sich am exponierte Port des SonarQube-Containers und fängt wie eine Machine-in-the-Middle alle
Requests ab und gleicht sie zuerst mit dem gestarteten SonarQube-Server ab. Dies geschieht, das SonarQube interne
Nutzerkonten (im Gegensatz zu externen Konten, also vom CAS/LDAP) zulässt, deren Abfrage im CAS dort im unnötig zu einem
Throttling führen könnte. Ist der Request noch nicht einem internen/externen Nutzerkonto authentifiziert, wird der 
Request von SonarQube mit HTTP401 abgelehnt. Ein eigener konfigurierbarer Throttling-Mechanismus in Sonarcarp sorgt für
eine zeitliche Verminderung der Angriffsoberfläche (wenn ein Schwellwert überschritten wird). Sonarcarp erkennt das 
HTTP401-Ergebnis und führt ein Redirect zum CAS-Login durch. Nach einer erfolgreichen Anmeldung wird zuerst ein 
CAS-Cookie ausgestellt. Dieser wird in einem erneuten Durchlauf (s. o.) aber erkannt und der Request wird zu SonarQube
hin kopiert und mit speziellen Authentifizierungsheadern versehen, die SonarQube die externe Authentifizierung anzeigen.
SonarQubes Antwort wird dann auf den ursprünglichen Request (den nach dem CAS-Login) zurückgespiegelt.

### Frontchannel Log-out

Es ist erwähnenswert, dass Logout-Calls keiner Session-Untersuchung unterliegen dürfen. D. h. es soll auch nicht-authentifizierten Anwender:innen möglich sein, die u. g. Logout-Endpunkte aufzurufen.

Um einen Frontchannel durchführen zu können, sind SonarQube-Session-Cookies nötig. Diese werden zur Laufzeit vorgehalten, um sie dann im Falle eines Backchannel-Log-outs verwenden zu können. Nach der Verwendung werden sie aus dem Speicher gelöscht. Frontchannel-Log-outs finden auf künstlichem Wege ebenfalls beim Backchannel-Log-out statt.

Frontchannel Log-out funktioniert aktuell wiefolgt:
1. Benutzer:in klickt auf den Logout-Navigationspunkt
2. Dies führt zu einem Request gegen den `/sonar/sessions/logout`-Endpunkt
3. Dies führt zu einem Request gegen den `/sonar/api/authentication/logout`-Endpunkt
4. Sonarcarp nimmt diesen Aufruf entgegen:
   - führt diesen Request zunächst NICHT gegen SonarQube aus
   - macht einen Redirect zum CAS-Logout, das einen Backchannel-Logout gegenüber allen registrierten Services (inkl. SonarQube) durchführt
5. Es folgt ein Backchannel-Logout, den Sonarcarp entgegennimmt und den eigenen Zustand aufräumt (siehe unten).

### Backchannel Log-out 

Backchannel Log-out funktioniert aktuell wiefolgt:

1. Benutzer:in loggt sich in einem anderen Service (oder durch Betätigung des Abmelden-Links im Warp-Menü) ab
2. Dies führt zu einem POST-Request von CAS gegen `/sonar/`
3. Sonarcarp nimmt diesen Aufruf entgegen:
   - Sonarcarp führt künstliches Frontchannel-Log-out mittels Request (inkl. Session- und XSRF-Token) gegen SonarQube aus
   - Sonarcarp macht einen Redirect zum CAS-Logout, das einen Backchannel-Logout gegenüber allen anderen Services durchführt
     - hierbei wird keine Rekursion erreicht, da CAS anhand der CAS-Session weiß, dass es keinen weiteren Logout durchführen muss.
4. Sonarcarp bereinigt die Session-Map von der aktuellen Konto-Cookie-Zuordnung

## Filter

Prozesse rund um das Thema Authentifizierung ist häufig komplex. Um die Verarbeitung unterschiedlicher Aspekte zu 
trennen und zu vereinfachen, wurden ähnliche Vorgehensverfahren in unterschiedliche Filter ausgelagert. Ein Filter soll
so möglichst sich immer nur um die Abwicklung eines Teils kümmern.

Diese Filter werden ineinander gesteckt, sodass eine Filterkette entsteht. Requests müssen für die erfolgreiche 
Verarbeitung alle diese Filter nacheinander passieren (für die Verkettung ist der carp-Serverteil verantwortlich, in 
umgekehrter Reihenfolge):

```
Client
⬇️     ⬆️
logHandler (loggt ggf.)
⬇️     ⬆️
backchannelLogoutHandler (erkennt und behandelt Backchannel-Logout (s. o.))
⬇️     ⬆️
throttlingHandler (erkennt HTTP401 und behandelt Client-Requests durch Throttling) 
⬇️     ⬆️
casHandler (unterscheidet Rest- von Browser-Requests, prüft Anfragen ggü. CAS)
⬇️     ⬆️
proxyHandler (bewältigt übrige Authentifizierungsteile und Umsetzung des Request-/Response-Proxyings)
⬇️     ⬆️
SonarQube
```

In jeder Filterstufe ist potenziell eine Unterbrechung der Kette (i. d. R. durch Abweisung des Requests) möglich.
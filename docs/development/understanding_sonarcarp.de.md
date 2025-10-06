# Die Wirkweise von sonarcarp verstehen

## Allgemeine Workflows im Sonarcarp

### Log-in

Mit SonarQube 2025 musste wegen einer mangelhaften Unterstützung das Sonar-CAS-Plugin durch einen CAS Authentication
Reverse Proxy (CARP) abgelöst werden.

Dieser Sonarcarp befindet sich am exponierte Port des SonarQube-Containers und fängt wie eine Machine-in-the-Middle alle
Requests ab und gleicht sie zuerst mit dem gestarteten SonarQube-Server ab. Dies geschieht, das SonarQube interne
Nutzerkonten (im Gegensatz zu externen Konten, also vom CAS/LDAP) zulässt, deren Abfrage im CAS dort im unnötig zu einem
Throttling führen könnte. Ist der Request noch nicht einem internen/externen Nutzerkonto authentifiziert, wird der 
Request von SonarQube mit HTTP401 abgelehnt. Ein eigener konfigurierbarer Throttlingmechanismus in Sonarcarp sorgt für
eine zeitliche Verminderung der Angriffsoberfläche (wenn ein Schwellwert überschritten wird). Sonarcarp erkennt das 
HTTP401-Ergebnis und führt ein Redirect zum CAS-Login durch. Nach einer erfolgreichen Anmeldung wird zuerst ein 
CAS-Cookie ausgestellt. Dieser wird in einem erneuten Durchlauf (s. o.) aber erkannt und der Request wird zu SonarQube
hin kopiert und mit speziellen Authentifizierungheadern versehen, die SonarQube die externe Authentifizierung anzeigen.
SonarQubes Antwort wird dann auf den ursprünglichen Request (den nach dem CAS-Login) zurückgespiegelt.

### Frontchannel Log-out

tbd

### Backchannel Log-out 

tbd

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
backchannelLogoutHandler (erkennt und behandelt Backchannel-Logout)
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
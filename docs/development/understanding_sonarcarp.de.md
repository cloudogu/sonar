# Die Wirkweise von sonarcarp verstehen

## Allgemeine Workflows im Sonarcarp

### Log-in

Mit SonarQube 2025 musste wegen einer mangelhaften Unterstützung das Sonar-CAS-Plugin durch einen CAS (Central Authentication Service) Authentication
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
hin kopiert und mit speziellen Authentifizierungsheadern `X-Forwarded-*` versehen, die SonarQube die externe Authentifizierung anzeigen.
SonarQubes Antwort wird dann auf den ursprünglichen Request (den nach dem CAS-Login) zurückgespiegelt.

Die folgenden Aspekte werden bei eingehenden Requests betrachtet:
- Welcher Client wird verwendet?
  - Browser: existiert ein Session-Cookie? 
    - wenn ja, verweist der Session-Cookie auf ein gültiges CAS-Service-Ticket?  
  - REST: existiert ein `Authorization`-Header?
- unterliegt ein Client gerade einem Throttling?

Bezüglich Requestantworten von CAS oder SonarQube werden erwartungsgemäß HTTP-Status und Antwortinhalt mit in den Betrachtungskontext gesetzt (hierzu später mehr).

Die folgende Grafik visualisiert Beteiligte und deren allgemeine Kommunikation: 
![Diagramm zwischen vier Hauptbeteiligten: Browser- und Rest-Clients, dem Sonar- und dem CAS-Dogu. Innerhalb des Sonar-Dogus fängt Sonarcarp auf Port 8080 eingehende Requests ab. Mittels go-cas interagiert es mit dem CAS-Dogu. Ansonsten leitet es Requests an SonarQube auf Port 9000 weiter](images/sonarcarp_and_sonarqube.png "Allgemeine Kommunikationspfade und deren Beteiligte im Sonar-Dogu")

Auf spezifische Kommunikationsfälle gehen die folgenden Abschnitte genauer ein.

#### CAS-Redirect

![CAS-Redirects wird im Browser-Szenario unterstützt. Dabei ermittelt go-cas anhand von Session-Cookies und CAS-Abfragen den Sitzungszustand. Existiert keine gültige SSO-Sitzung im CAS für das verwendete Konto, weist Sonarcarp die Abfrage mit einem Redirect auf die CAS-Seite um](images/sonarcarp_and_sonarqube-cas-redirect.png "Ein:e Anwender:in wird bei unbekannter Session auf die CAS-Login-Seite umgeleitet, um sich dort für Single-Sign-On anzumelden.")

CAS-Redirects wird im Browser-Szenario unterstützt. Dabei ermittelt go-cas anhand von Session-Cookies und CAS-Abfragen den Sitzungszustand. Existiert keine gültige SSO-Sitzung im CAS für das verwendete Konto, weist Sonarcarp die Abfrage mit einem Redirect auf die CAS-Seite um. An dieser Stelle kann sich eine Person mit den eigenen Zugangsdaten anmelden. CAS erzeugt bei Anmeldeerfolg im Browser einen `TGC`-Cookie an und leitet auf die ursprüngliche URL weiter.

#### Session-Cookie

In dem Augenblick, in dem XYZ TODO


#### Authorization-Header

Dieser Abschnitt bezieht sich auf die Authentifizierungsmethoden `Authorization: Basic {Username und Passwort Base64 enkodiert}` bzw. `Authorization: Bearer {SonarQube-Token}`. Da eine Browsersession nach dem Login auf der CAS-Login-Seite durch einen Cookie `_cas_session` identifiziert, werden alle Anfragen mit einem `Authorization`-Header

#### Throttling

Der Aufbau durch untergeordnete Filter (s. u.) ermöglicht ein Throttling unabhängig davon, ob Request nun von Browsern oder REST-Clients gestellt wurden und diese durch SonarQube selbst oder durch den CAS beantwortet wurden. Dieses leistet der `ThrottlingHandler`, der eine [Token-Bucket](https://de.wikipedia.org/wiki/Token-Bucket-Algorithmus)-Implementierung verwendet.

Dieser überprüft anhand des HTTP-Response-Status, ob ein Wert `HTTP 401 Unauthorized` vorliegt. In diesem Fall zählt der ThrottlingHandler je Throttling-Client einen vorher festgelegten Token-Wert (siehe Wert `limiter-burst-size` in `carp.yaml.tpl`) herunter. Der Throttling-Client setzt sich aus Login und einer IP-Adresse zusammen, um falsch-positive Blockierungen zu vermeiden. 

| Throttling-Client-Anteil | Wert                             | Beispielwert                        | Fehlwert                         |
|--------------------------|----------------------------------|-------------------------------------|----------------------------------|
| Konto                    | Kontologin                       | your.cas.user@example.invalid       | sonarcarp.throttling@ces.invalid |
| IP-Adresse               | IP-Adresse vor nginx-Proxyierung | Inhalt von Header `X-Forwarded-For` | "" (bei Requests von Dogus)      |

Ab dem Augenblick, in dem kein Token mehr generieren lässt, sind für Requests für einen solchen Throttling-Client nicht mehr erlaubt. Alle folgenden Requests werden für den Throttling-Client frühzeitig mit `HTTP 429 Too many requests` quittiert und nicht weiter verarbeitet. Es muss so lange gewartet werden, bis sich über eine Zeit wieder Tokens angesammelt haben.

Sonarcarp ist stark auf die Header `X-Forwarded-*` gegenüber SonarQube zur Authentifizierung angewiesen ist, um eine Authentifizierung von Konten als "erfolgt" darzustellen. Diese Header sollten im Gegensatz zu den oben beschriebenen `Authorization`-Headern **niemals** im regulären Browserbetrieb auftreten. Daher sieht Sonarcarp es als Angriffsversuch auf die Authentifizierung an, wenn ein Client diese Header bereits verwendet. In diesem Falle werden sofort alle übrigen Tokens aufgebraucht, das zu den o. g. Folgen führt. Ein Logging dieses Ereignisses findet ebenfalls statt, um (je nach Sicherheitslösung) sofortige oder nachträgliche Meldung und Nachverfolgung zu ermöglichen.

### Log-out


#### Frontchannel Log-out

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

#### Backchannel Log-out 

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
throttlingHandler (erkennt HTTP401 und behandelt Client-Requests durch Throttling) 
⬇️     ⬆️
casHandler (unterscheidet Rest- von Browser-Requests, prüft Anfragen ggü. CAS)
⬇️     ⬆️
proxyHandler (bewältigt übrige Authentifizierungsteile und Umsetzung des Request-/Response-Proxyings)
⬇️     ⬆️
SonarQube
```

In jeder Filterstufe ist potenziell eine Unterbrechung der Kette (i. d. R. durch Abweisung des Requests) möglich.
# Todos
* opt/sonar/web durch den content von sonarqube-webapp.zip ersetzen, wenn das Community-Branch-Plugin installiert ist
  * Funktion zum Ersetzen existiert bereits, es fehlt der Check, ob das Plugin installiert ist
  * Das Ersetzen muss an der richtigen Stelle stattfinden, wir schreiben zum Beispiel für removeGetBeamerCalls & disableProductNewsIcon direkt in die web-Dateien
* Überlegen, wie der Code am besten im Repo liegen soll 
  * als .zip? Entpackt?
* Testen, ob der Fix funktioniert
  * siehe /docs/development/community-branch-plugin_de.md
* Upgrade-Dokumentation schreiben
  * wo findet man den Code vom Community-Branch-Plugin? Wie ersetzt man den Code?
* Release auf Basis von Sonarqube 25.12.0.0-8
  * dieser Branch basiert auf develop
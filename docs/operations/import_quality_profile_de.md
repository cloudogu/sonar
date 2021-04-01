# Funktionen

Um Qualitätsprofile in das SonarQube-Dogu zu importieren, führen Sie bitte folgende Schritte durch:

- Speichern sie die Qualitätsprofile (im XML-Format) unter /var/lib/ces/sonar/volumes/qualityprofiles ab
- Starten Sie das sonar-Dogu neu (z.B. mittels `docker restart sonar`)


Die Profile werden automatisch in das SonarQube-Dogu importiert und sind nutzbar, sobald das Dogu vollständig gestartet ist.

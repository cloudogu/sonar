# Funktionen

Um Qualitätsprofile in das SonarQube-Dogu zu importieren, führen Sie bitte folgende Schritte durch:

- Speichern sie die Qualitätsprofile (im XML-Format) unter ``/var/lib/qualityprofiles`` ab, z.B. mittels ``kubectl cp``
- Starten Sie das sonar-Dogu neu (z.B. mittels `kubectl rollout restart deployment/sonar`)


Die Profile werden automatisch in das SonarQube-Dogu importiert und sind nutzbar, sobald das Dogu vollständig gestartet ist.

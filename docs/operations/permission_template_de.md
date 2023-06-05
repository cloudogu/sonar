# Permission template

„Permission Templates“ sind ein Mechanismus von SonarQube, um Vorlagen für Projektberechtigungen zu erstellen. Die
Admin-Gruppe des Cloudogu EcoSystems wird der Standardvorlage („Default Template“) beim Start des Dogus automatisch 
hinzugefügt, um sicherzustellen, dass Nutzer mit der Admin-Gruppe die nötigen Berechtigungen auf allen Projekten besitzen.

Die Admin-Gruppe des Cloudogu EcoSystems wird dabei mit folgenden Berechtigungen hinzugefügt:
- admin
- codeviewer
- issueadmin
- securityhotspotadmin
- scan
- user

Die Einstellungen können unter `Administration -> Security -> Permisssion Templates` überprüft werden.
*siehe setup.json für weitere Informationen*

# Korrektur von falsch konfigurierten Projekten

Neue Projekte, die mit der Standardvorlage angelegt wurden, mit der die Admin-Gruppe nicht verknüpft war, können 
nachträglich korrigiert werden.

Dazu sind folgende Schritte durchzuführen:
- Konfigurationsschlüssel `/config/sonar/amend_projects_with_ces_admin_permissions` auf den Wert `all` setzen
- Dogu neu starten z.B. mittels `cesapp restart sonar`
- Dies sorgt dafür, dass die Admin-Gruppe allen Projekten mit den nötigen Berechtigungen hinzugefügt wird.
- Nach erfolgreicher Korrektur der Berechtigungen wird der Konfigurationsschlüssel auf den Wert `none` gesetzt.

*siehe Beschreibung `configuration` in der Datei `dogu.json` für weitere Informationen*

Die Gruppe wird mittels API-Endpunkt `permissions/add_group` hinzugefügt.

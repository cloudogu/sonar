# Release Notes

Im Folgenden finden Sie die Release Notes für das SonarQube-Dogu. 

Technische Details zu einem Release finden Sie im zugehörigen [Changelog](https://docs.cloudogu.com/de/docs/dogus/sonar/CHANGELOG/).

## [Unreleased]
* „Fix project permission“ für CES Multinode ermöglicht.
  * Wenn `amend_projects_with_ces_admin_permissions` auf einen aktuellen Zeitstempel gesetzt ist, wird die ces-admin Gruppe aktiviert, um alle Projekte zu verwalten.
    Der Zeitstempel muss im Format `YYYY-MM-DD hh:mm:ss` sein (z.B. `2025-03-20 09:30:00`).
    Das Dogu speichert intern den Zeitstempel der letzten Ausführung und vergleicht diesen Zeitstempel mit dem Zeitstempel aus der Konfiguration.
    Ist der in der Konfiguration eingetragene Zeitstempel „neuer“, werden die Projekte beim Neustart des Dogu korrigiert.

## [v25.1.0-1] - 2025-03-04
* Das Dogu bietet nun die SonarQube-Version 2025.1 (LTS) an. Die Release Notes von SonarQube finden Sie [hier](https://docs.sonarsource.com/sonarqube-server/2025.1/server-upgrade-and-maintenance/release-notes-and-notices/release-notes/).
  Eine Liste der im aktuellen Major-release enthaltenen Verbesserungen findet sich [hier](https://sonarsource.atlassian.net/issues/?jql=project%20%3D%2010139%20AND%20fixVersion%20%3D%2015952%20AND%20issuetype%20%21%3D%20Task)

## [v9.9.8-2] - 2025-02-12
* Wir haben nur technische Änderungen vorgenommen. Näheres finden Sie in den Changelogs.

## [v9.9.8-1] - 2025-01-13
* Das Dogu bietet nun die SonarQube-Version 9.9.8 an. Die Release Notes von SonarQube finden Sie [hier](https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/release-upgrade-notes/#release-9.9-upgrade-notes).
Eine Liste der im aktuellen Patch-release enthaltenen Verbesserungen findet sich [hier](https://sonarsource.atlassian.net/issues/?jql=project%20%3D%2010139%20AND%20fixVersion%20%3D%2016011%20AND%20issuetype%20%21%3D%20Task)

## 9.9.7-1
* Das Dogu bietet nun die SonarQube-Version 9.9.7 an. Die Release Notes von SonarQube finden Sie [hier](https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/release-upgrade-notes/#release-9.9-upgrade-notes).
Eine Liste der im aktuellen Patch-release enthaltenen Verbesserungen findet sich [hier](https://sonarsource.atlassian.net/issues/?jql=project%20%3D%2010139%20AND%20fixVersion%20%3D%2015864%20AND%20issuetype%20%21%3D%20Task)

## 9.9.5-5
Wir haben nur technische Änderungen vorgenommen. Näheres finden Sie in den Changelogs.

## 9.9.5-4
- Die Cloudogu-eigenen Quellen werden von der MIT-Lizenz auf die AGPL-3.0-only relizensiert.

## 9.9.5-3
* Behebung von kritischem CVE-2024-41110 in Bibliotheksabhängigkeiten. Diese Schwachstelle konnte jedoch nicht aktiv ausgenutzt werden.

## 9.9.5-2
Wir haben nur technische Änderungen vorgenommen. Näheres finden Sie in den Changelogs.

## 9.9.5-1

* Das Dogu bietet nun die SonarQube-Version LTS 9.9.5 an. Die Release Notes von SonarQube finden Sie [hier](https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/release-upgrade-notes/#release-9.9-upgrade-notes).
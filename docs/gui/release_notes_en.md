# Release Notes

Below you will find the release notes for the SonarQube Dogu. 

Technical details on a release can be found in the corresponding [Changelog](https://docs.cloudogu.com/en/docs/dogus/sonar/CHANGELOG/).

## [Unreleased]
* Enable "fix project permission" for CES Multinode
  * If `amend_projects_with_ces_admin_permissions` is set to a current timestamp, the ces-admin group will be enabled to administer all projects.
    The timestamp has to be in the format `YYYY-MM-DD hh:mm:ss` (e.g. `2025-03-20 09:30:00`).
    The Dogu saves the timestamp of the last execution internally and compares this timestamp with the timestamp from the configuration.
    If the timestamp entered in the configuration is “newer”, the projects are corrected when the dogu is restarted.

## [v25.1.0-1] - 2025-03-04
* The Dogu now offers SonarQube version 2025.1 (LTS). The SonarQube release notes can be found [here](https://docs.sonarsource.com/sonarqube-server/2025.1/server-upgrade-and-maintenance/release-notes-and-notices/release-notes/).
  A list of the improvements included in the current major release can be found [here](https://sonarsource.atlassian.net/issues/?jql=project%20%3D%2010139%20AND%20fixVersion%20%3D%2015952%20AND%20issuetype%20%21%3D%20Task)

## [v9.9.8-2] - 2025-02-12
* We have only made technical changes. You can find more details in the changelogs.

## [v9.9.8-1] - 2025-01-13
* The Dogu now offers SonarQube version 9.9.8. The SonarQube release notes can be found [here](https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/release-upgrade-notes/#release-9.9-upgrade-notes).
A list of the improvements included in the current patch release can be found [here](https://sonarsource.atlassian.net/issues/?jql=project%20%3D%2010139%20AND%20fixVersion%20%3D%2016011%20AND%20issuetype%20%21%3D%20Task)

## 9.9.7-1
* The Dogu now offers SonarQube version 9.9.7. The SonarQube release notes can be found [here](https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/release-upgrade-notes/#release-9.9-upgrade-notes).
A list of the improvements included in the current patch release can be found [here](https://sonarsource.atlassian.net/issues/?jql=project%20%3D%2010139%20AND%20fixVersion%20%3D%2015864%20AND%20issuetype%20%21%3D%20Task)

## 9.9.5-5
We have only made technical changes. You can find more details in the changelogs.

## 9.9.5-4
- Relicense own code to AGPL-3-only

## 9.9.5-3
* Fix of critical CVE-2024-41110 in library dependencies. This vulnerability could not be actively exploited, though.

## 9.9.5-2
We have only made technical changes. You can find more details in the changelogs.

## 9.9.5-1

* The Dogu now offers the SonarQube version LTS 9.9.5. The release notes of SonarQube can be found [here](https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/release-upgrade-notes/#release-9.9-upgrade-notes).
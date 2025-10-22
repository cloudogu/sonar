# Release Notes

Below you will find the release notes for the SonarQube Dogu. 

Technical details on a release can be found in the corresponding [Changelog](https://docs.cloudogu.com/en/docs/dogus/sonar/CHANGELOG/).

## [Unreleased]

## [v25.1.0-6] - 2025-10-22
* Validation has been added to allow only upgrades from version 9 to 25.
* The Sonar CAS plugin has been replaced with a new authentication method.
* Sharing telemetry data with SonarSource has been disabled for added security.

## [v25.1.0-5] - 2025-05-13
* We have only made technical changes. You can find more details in the changelogs.

## [v25.1.0-4] - 2025-04-29

### Changed
- Usage of memory and CPU was optimized for the Kubernetes Multinode environment.

## [v25.1.0-3] - 2025-04-16
* This release adds the option to load sonar quality profiles from a remote url.

## [v25.1.0-2] - 2025-03-27
* This release fixes authorization problems when the Dogu is executed in the CES multinode context. Project authorizations may be activated for the default admin group.

## [v25.1.0-1] - 2025-03-04
* The Dogu now offers SonarQube version 2025.1 (LTS). The SonarQube release notes can be found [here](https://docs.sonarsource.com/sonarqube-server/2025.1/server-upgrade-and-maintenance/release-notes-and-notices/release-notes/).
  A list of the improvements included in the current major release can be found [here](https://sonarsource.atlassian.net/issues/?jql=project%20%3D%2010139%20AND%20fixVersion%20%3D%2015952%20AND%20issuetype%20%21%3D%20Task)

## [v9.9.8-2] - 2025-02-12
* We have only made technical changes. You can find more details in the changelogs.

## [v9.9.8-1] - 2025-01-13
* The Dogu now offers SonarQube version 9.9.8. The SonarQube release notes can be found [here](https://docs.sonarsource.com/sonarqube-server/9.9/setup-and-upgrade/release-upgrade-notes/).
A list of the improvements included in the current patch release can be found [here](https://sonarsource.atlassian.net/issues/?jql=project%20%3D%2010139%20AND%20fixVersion%20%3D%2016011%20AND%20issuetype%20%21%3D%20Task)

## 9.9.7-1
* The Dogu now offers SonarQube version 9.9.7. The SonarQube release notes can be found [here](https://docs.sonarsource.com/sonarqube-server/9.9/setup-and-upgrade/release-upgrade-notes/).
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

* The Dogu now offers the SonarQube version LTS 9.9.5. The release notes of SonarQube can be found [here](https://docs.sonarsource.com/sonarqube-server/9.9/setup-and-upgrade/release-upgrade-notes/).
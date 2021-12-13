# SonarQube Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v8.9.2-2] - 2021-12-13

### Fixed
- disable jndi lookup due to a vulnerability (69, https://community.sonarsource.com/t/sonarqube-and-the-log4j-vulnerability/54721)

## [v8.9.2-1] - 2021-11-24
- Re-release of 8.9.0-5 to use correct version

## [v8.9.0-5] - 2021-11-23
### Added
- Make log level configurable

### Changed
- Upgrade to SonarQube 8.9.2; #67
- Upgrade to java base image 11.0.11-2
- Switch to dogu.json format v2
- Switch to Cypress/Cucumber integration tests
- Upgrade to sonar-cas-plugin v4.2.0

## [v8.9.0-4] - 2021-07-28
### Added
- Add CAS proxy ticketing (#65)

### Changed
- Switch from CAS specification 2.0 to 3.0 (#65)

## [v8.9.0-3] - 2021-07-19
### Fixed
- Fix CAS authentication error with previously logged-in users during migration (#63)

## [v8.9.0-2] - 2021-06-16
### Removed
- Removed global proxy mechanism (#61)

## [v8.9.0-1] - 2021-06-03

### Added
- agent settings for the new version of the community-branch-plugin (1.8.0+)

### Changed
- update to new LTS version 8.9 (#59)
- update CAS plugin to version 4.0.0
- any installed versions of the community-branch-plugin will be removed when upgrading to SonarQube 8.9
- SonarQube inlines a lot of functionality that was previously supplied as plugin. Please refer to the SonarQube [documentation](https://docs.sonarqube.org/latest/instance-administration/plugin-version-matrix/) for detailed information. The following plugins will be moved to `extensions/deprecated-plugins` if the upgrade script detects them (#59):
  - C# Code Quality and Security
  - CFamily Code Quality and Security
  - COBOL Code Quality
  - Git
  - GitHub Authentication for SonarQube
  - JaCoCo
  - Java Code Quality and Security
  - PHP Code Quality and Security
  - Python Code Quality and Security
  - RPG Code Quality
  - SAML 2.0 Authentication for SonarQube 	Bundled
  - SonarABAP
  - SonarApex
  - SonarCSS
  - SonarFlex
  - SonarGo
  - SonarHTML
  - SonarJS
  - SonarKotlin
  - SonarPLI
  - SonarPLSQL
  - SonarRuby
  - SonarScala
  - SonarSwift
  - SonarTS
  - SonarTSQL
  - SonarVB6
  - SonarXML
  - Svn
  - VB.NET Code Quality and Security

## [v7.9.4-4] - 2021-02-18
### Changed
- Members of the CES administrator group receive project admin permissions for new projects (#3)
- CES_ADMIN group can be enabled to administer all projects using the key `amend_projects_with_ces_admin_permissions`
(see `dogu.json` for details) (#3)

## [v7.9.4-3] - 2021-02-01
### Fixed
- pass truststore as jvm options to compute engine (#56)

### Changed
- Update dogu-build-lib to `v1.1.1`
- Update zalenium-build-lib to `v2.1.0`
- toggle video recording with build parameter (#53)

## [v7.9.4-2] - 2020-12-14
### Added
- Added the ability to configure the memory limits with `cesapp edit-config`
- Ability to configure the `MaxRamPercentage` and `MinRamPercentage` for the sonar main/web/search/compute processes inside the container via `cesapp edit-conf` (#51)

## [v7.9.4-1] - 2020-11-13
### Changed
- Upgrade to SonarQube 7.9.4 LTS; #49
- Upgrade java base image to 11.0.5-4

## [v7.9.3-3] - 2020-09-07
### Changed
- Changed order of plugin installation and quality profile import (#46)
    - Quality profiles may depend on plugins. This change guarantees a restart of SonarQube if quality profiles are about to be imported
    - There will be no additional restart if no quality profiles are supposed to be imported

## [v7.9.3-2] - 2020-08-14
### Changed
* Removed sonarqubedoguadmin
* An admin with a random name is generated at every startup for configuration and removed after startup

## [v7.9.3-1] - 2020-06-18
### Fixed
* Fixed bug where a new dogu admin user was created on each restart

### Added
* Add automated release process
* The pre-Upgrade script now will delete es6 cache when upgrading from 7.9.1-4 or lower

### Changed 
* Update SonarQube from 7.9.1 to 7.9.3

## [7.9.1-4] - 2020-01-29

### Added
* Compatibility to community branch plugin 

## [7.9.1-3] - 2020-01-24

### Changed
* Configure update center url before starting sonar
* Restart sonar after installing default plugins

## [7.9.1-2] - 2020-01-16

### Added

* config key `sonar.plugins.default` which may contain a comma separated list with plugin names that are installed on startup

## [7.9.1-1] - 2020-01-02

SonarQube 7.9.1 LTS

Make sure to upgrade ces-commons package to at least v0.2.0 before upgrading to this version.

### Changed
* Upgrade to Java 11
* Upgrade to SonarQube 7.9.1
* Upgrade sonar-cas-plugin

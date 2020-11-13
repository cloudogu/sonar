# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
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
* Update Sonar from 7.9.1 to 7.9.3

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

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


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

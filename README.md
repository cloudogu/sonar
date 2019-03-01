<img src="https://cloudogu.com/images/dogus/sonarqube.png" alt="sonar logo" height="100px">


[![GitHub license](https://img.shields.io/github/license/cloudogu/sonar.svg)](https://github.com/cloudogu/sonar/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/cloudogu/sonar.svg)](https://github.com/cloudogu/sonar/releases)

# SonarQube Dogu

## About this Dogu

**Name:** official/sonar

**Description:** [SonarQube](https://en.wikipedia.org/wiki/SonarQube)  is an open source platform developed by SonarSource for continuous inspection of code quality to perform automatic reviews with static analysis of code to detect bugs, code smells, and security vulnerabilities on 20+ programming languages.

**Website:** https://www.sonarqube.org/

**Dependencies:** postgresql, cas, nginx, postfix

**Persistent Dogu Admin User:**

This SonarQube Dogu holds a persistent user called "sonarqubedoguadmin" for configuration purposes which should not be removed.

## Importing Quality Profiles

To import quality profiles into the SonarQube dogu please follow the steps described here: https://github.com/cloudogu/ecosystem/blob/develop/docs/docs/user-guide/sonar.md

## Installation Ecosystem
```
cesapp install official/sonar

cesapp start sonar
```

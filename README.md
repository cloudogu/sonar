<img src="https://cloudogu.com/images/dogus/sonarqube.png" alt="sonar logo" height="100px">


[![GitHub license](https://img.shields.io/github/license/cloudogu/sonar.svg)](https://github.com/cloudogu/sonar/blob/develop/LICENSE)
[![GitHub release](https://img.shields.io/github/release/cloudogu/sonar.svg)](https://github.com/cloudogu/sonar/releases)

# SonarQube Dogu

## About this Dogu

**Name:** official/sonar

**Description:** [SonarQube](https://en.wikipedia.org/wiki/SonarQube)  is an open source platform developed by SonarSource for continuous inspection of code quality to perform automatic reviews with static analysis of code to detect bugs, code smells, and security vulnerabilities on 20+ programming languages.

**Website:** https://www.sonarqube.org/

**Docs:** https://docs.sonarqube.org/display/SONAR/Documentation

**Dependencies:** postgresql, cas, nginx, postfix

**Persistent Dogu Admin User:**

This SonarQube Dogu holds a persistent user called "sonarqubedoguadmin" for configuration purposes which should not be removed.

## Importing Quality Profiles

To import quality profiles into the SonarQube dogu please follow the steps described here: https://github.com/cloudogu/ecosystem/blob/develop/docs/docs/user-guide/sonar.md

## Installation in Cloudogu EcoSystem
```
cesapp install official/sonar

cesapp start sonar
```

---
## Documentation
The documentation can be found inside the [docs](https://github.com/cloudogu/sonar/tree/develop/docs) directory

### What is the Cloudogu EcoSystem?
The Cloudogu EcoSystem is an open platform, which lets you choose how and where your team creates great software. Each service or tool is delivered as a Dogu, a Docker container. Each Dogu can easily be integrated in your environment just by pulling it from our registry. We have a growing number of ready-to-use Dogus, e.g. SCM-Manager, Jenkins, Nexus, SonarQube, Redmine and many more. Every Dogu can be tailored to your specific needs. Take advantage of a central authentication service, a dynamic navigation, that lets you easily switch between the web UIs and a smart configuration magic, which automatically detects and responds to dependencies between Dogus. The Cloudogu EcoSystem is open source and it runs either on-premises or in the cloud. The Cloudogu EcoSystem is developed by Cloudogu GmbH under [MIT License](https://cloudogu.com/license.html).

### How to get in touch?
Want to talk to the Cloudogu team? Need help or support? There are several ways to get in touch with us:

* [Website](https://cloudogu.com)
* [myCloudogu-Forum](https://forum.cloudogu.com/topic/34?ctx=1)
* [Email hello@cloudogu.com](mailto:hello@cloudogu.com)

---
&copy; 2020 Cloudogu GmbH - MADE WITH :heart:&nbsp;FOR DEV ADDICTS. [Legal notice / Impressum](https://cloudogu.com/imprint.html)

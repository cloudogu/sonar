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

## Documentation
The documentation can be found inside the [docs](https://github.com/cloudogu/sonar/tree/develop/docs) directory

---

## What is the Cloudogu EcoSystem?
The Cloudogu EcoSystem is an open platform, which lets you choose how and where your team creates great software. Each service or tool is delivered as a Dogu, a Docker container. Each Dogu can easily be integrated in your environment just by pulling it from our registry.

We have a growing number of ready-to-use Dogus, e.g. SCM-Manager, Jenkins, Nexus Repository, SonarQube, Redmine and many more. Every Dogu can be tailored to your specific needs. Take advantage of a central authentication service, a dynamic navigation, that lets you easily switch between the web UIs and a smart configuration magic, which automatically detects and responds to dependencies between Dogus.

The Cloudogu EcoSystem is open source and it runs either on-premises or in the cloud. The Cloudogu EcoSystem is developed by Cloudogu GmbH under [AGPL-3.0-only](https://spdx.org/licenses/AGPL-3.0-only.html).

## License
Copyright © 2020 - present Cloudogu GmbH
This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.
You should have received a copy of the GNU Affero General Public License along with this program. If not, see https://www.gnu.org/licenses/.
See [LICENSE](LICENSE) for details.


---
MADE WITH :heart:&nbsp;FOR DEV ADDICTS. [Legal notice / Imprint](https://cloudogu.com/en/imprint/?mtm_campaign=ecosystem&mtm_kwd=imprint&mtm_source=github&mtm_medium=link)


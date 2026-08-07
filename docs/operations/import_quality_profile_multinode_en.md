# Operations

To import quality profiles into the SonarQube dogu please follow these steps:

- Move your quality profile files (in XML format) to `/var/lib/qualityprofiles`, for example with `kubectl cp`
- Restart the sonar dogu (e.g. with `kubectl rollout restart deployment/sonar`)

The profiles will be imported automatically into the SonarQube dogu and can be used as soon as the dogu has fully started.

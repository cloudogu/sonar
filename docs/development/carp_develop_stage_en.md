# CARP Development Mode

## Adjust configuration
Adjust `carp.yaml`.

## Allow external SonarQube in CES-CAS

To test some Dogus locally, it is necessary to put the CAS into development mode.
This allows all applications to authenticate via the CAS, even if they are not
configured there.
To do this, the stage of the EcoSystem must be set to
`development` and the Dogu must be restarted:

```
etcdctl set /config/_global/stage development
docker restart cas
```

## Start SonarQube
```
export SONAR_CAS_LOCAL_IP=192.168.56.1
docker compose up -d && docker compose logs sonar -f
```

Note: If sonar does not start, it could be due to permissions. To fix this, simply execute `sudo chmod -R 777 ./sonar-home`, for example.

## Start sonarcarp

A Golang debugging configuration must exist and run in your IDE.

## Test CAS login

1. Open this URL in your browser: http://localhost:8080/sonar <!-- markdown-link-check-disable-line -->
    - If the call is successful, you will be redirected to the CAS configured under this `carp.yaml` property: `cas-url`
2. Log in to CAS.
    - If the login is successful, you will be redirected to SonarQube, which was configured under this `carp.yaml` property: `https://localhost:9000/sonar/` <!-- markdown-link-check-disable-line -->


## Test CAS logout

<!-- markdown-link-check-disable-next-line -->
If unsuccessful, manually entering the URL http://localhost:8080/sonar/sessions/logout may help. This URL is
configured in this `carp.yaml` property: `logout-path`

## Clean up

Remove SonarQube
```
docker compose stop && docker compose rm -f
```

It may be necessary to delete these directories with root privileges, as they are created by the container:

```sudo rm -rf \
   sonar-home/data/ \
   sonar-home/logs/ \
   sonar-home/temp/ \
   sonar-home/plugins
```
# Easier scanning with Sonar-scanner-cli

Due to common certificate errors, it is not that easy to use the sonar scanner in a local system with self-signed certificates.

To avoid installing a whole stack of SCM Manager, Jenkins, etc., it is easier to modify a Sonar scanner with your own certificate:

1. Generate a SonarQube token, e.g., at https://example.invalid/sonar/account/security.
   - In this example: `sqa_3ffb7e36dee85c27ab1b3cca58e0dea400068f70`
2. Select the codebase to be scanned
3. Copy the certificate to a file and store it in the codebase's file system
   - CES-VM: `etcdctl get /config/_global/certificate/server.crt > /vagrant/ces.pem`
4. Copy the certificate to the codebase directory
5. From the codebase directory (`$PWD -> /usr/src/`)
   1. Start Sonar scanner,
   2. Import the certificate, and
   3. Scan

```shell
docker run \                         
    --rm -u 0 \
    -e SONAR_HOST_URL="https://example.invalid/sonar"  \
    -e SONAR_TOKEN="sqa_3ffb7e36dee85c27ab1b3cca58e0dea400068f70" \
    -v "${PWD}:/usr/src" -it --entrypoint sh \
    sonarsource/sonar-scanner-cli

# You will be taken to a shell. Here we continue:
cd /usr/lib/jvm/java-17-openjdk/lib/security
keytool -import -trustcacerts -noprompt -alias sonarqube -file /usr/src/ces.pem -keystore cacerts -storepass changeit
cd -
sonar-scanner
exit
```

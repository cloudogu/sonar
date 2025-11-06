# Einfacher mit Sonar-scanner-cli scannen

Wegen üblicher Zertifikatsfehler ist es nicht so ganz einfach, in einem lokalen System mit selbst-signierten Zertifikaten den sonar-scanner zu verwenden.

Um weiterhin nicht einen ganzen Stack von SCM-Manager, Jenkins usw. zu installieren, lässt sich leichter Abhilfe schaffen, wenn man einen Sonar-Scanner mit einem eigenen Zertifikat modifiziert:

1. SonarQube-Token erzeugen, z. B. unter https://example.invalid/sonar/account/security
   - in diesem Beispiel: `sqa_3ffb7e36dee85c27ab1b3cca58e0dea400068f70`
2. Codebase auswählen, die gescannt werden soll
3. Zertifikat in eine Datei kopieren und im Dateisystem der Codebase hinterlegen
   - CES-VM: `etcdctl get /config/_global/certificate/server.crt > /vagrant/ces.pem`
4. Zertifikat in das Verzeichnis der Codebase kopieren
5. Aus dem Verzeichnis der Codebase heraus (`$PWD -> /usr/src/`) 
   1. Sonar-scanner starten, 
   2. Zertifikat importieren und 
   3. scannen

```shell
docker run \                         
    --rm -u 0 \
    -e SONAR_HOST_URL="https://example.invalid/sonar"  \
    -e SONAR_TOKEN="sqa_3ffb7e36dee85c27ab1b3cca58e0dea400068f70" \
    -v "${PWD}:/usr/src" -it --entrypoint sh \
    sonarsource/sonar-scanner-cli

# man landet in einer shell. Hierin geht es weiter:
cd /usr/lib/jvm/java-17-openjdk/lib/security
keytool -import -trustcacerts -noprompt -alias sonarqube -file /usr/src/ces.pem -keystore cacerts -storepass changeit
cd -
sonar-scanner
exit
```

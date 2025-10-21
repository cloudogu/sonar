# CARP-Remote-Debugging

Es ist möglich, sonarcarp während der Ausführung in einem bestehenden Ökosystem zu debuggen, um die Analyse bestimmter 
Verhaltensweisen zu erleichtern.

# Remote-Debugging aktivieren

Um das Remote-Debugging für sonarcarp zu aktivieren, müssen die `.env`-Datei anpassen, indem Sie die folgende Zeile hinzufügen:

```
DEBUG=true
```

Dadurch wird ein neues Sonar-Image erstellt, das [Delve](https://github.com/go-delve/delve/tree/master) enthält, und sonarcarp
mit `delve` gestartet, das auf eine Remote-Debugging-Sitzung auf Port `2345` wartet.

# Portweiterleitung für Debugging-Port

Um auf den Remote-Debugging-Port zugreifen zu können, müssen wir den Port noch weiterleiten, damit er für den Remote-Debugger zugänglich ist.

## CES-Multinode

Um sonarcarp in CES Multinode zu debuggen, müssen Sie lediglich eine Portweiterleitung für Port 2345 zum Sonar-Pod erstellen.
Die Portweiterleitung kann mit kubectl oder mit k9s erstellt werden.

```shell
kubectl port-forward sonar-6d7b47cd7b-pqprr 2345:2345
```

Der Remote-Debugger kann dann eine Verbindung zu `localhost:2345` herstellen.

## CES-VM

Wegen der Schlüsselgestaltung von Services im etcd (`/services/`) ist es nicht möglich, solch ein Debug-Image als Dogu
zu deployen. Hierzu müsste der Port aus der VM heraus exportiert werden, das üblicherweise mittels `ExposedPort` in 
`dogu.json` geschieht. Dies führt jedoch zu gänzlich unterschiedlichen 

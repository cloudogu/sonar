# CARP Remote Debugging

With sonarcarp it is possible to debug the carp while running within an existing ecosystem to facilitate the analysis 
of specific behaviors.

# Enable Remote Debugging

In order to enable remote debugging for sonarcarp you need to adjust your `.env` file by adding the line:

```
DEBUG=true
```

This creates a new sonar image that contains [Delve](https://github.com/go-delve/delve/tree/master) and starts sonarcarp
with `delve`, which waits for a remote debugging session on port `2345`.

# Port Forwarding for Debugging-Port

To access the remote debugging port, we still need to forward the port to become accessible by the remote debugger.

## CES-Multinode

To debug the sonarcarp in CES Multinode, you only need to create a port forward for port 2345 to the Sonar pod.
The port forward can be created with kubectl or with k9s.

```shell
kubectl port-forward sonar-6d7b47cd7b-pqprr 2345:2345
```

The remote debugger can then connect to `localhost:2345`.

## CES-VM

It takes some more effort to debug the sonarcarp in a CES VM.

Add the following `ExposedPort` line to the `dogu.json` to expose the port to outside the VM 

**WARNING**
Be sure NOT TO COMMIT this line because it fully exposes the Dogu to the outside without any restrictions. 

```
  "ExposedPorts": [
    { "Type": "tcp", "Container": 2345, "Host": 2345 }
  ]
```

Then disable the VM's firewall so the port can be actually connected.
```shell
sudo ufw disable
```

Then add the customized `dogu.json` to your registry

```shell
cd /vagrant/containers/sonar # or whereever your sonarqube repo is located at
cesapp build . && cesapp start sonar
```

Because the `cesapp` does not handle the necessary environment variables that are required for the `dlv`-enabled build this must happen now. 
Replace the dogu image with these two calls:
```shell
make docker-build
cesapp recreate --start sonar
```

As above for the Multinode installation, the dogu will not get healthy until you connect your debugger with `dlv`

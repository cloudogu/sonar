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

It takes some more effort (basically two changed files and a disabled firewall) to debug the sonarcarp in a CES VM.

**`dogu.json`**
Add the following `ExposedPort` line to the `dogu.json` to expose the port to outside the VM 

**WARNING**
Be sure NOT TO COMMIT this line because it fully exposes the Dogu to the outside without any restrictions. 

```
  "ExposedPorts": [
    { "Type": "tcp", "Container": 2345, "Host": 2345 }
  ]
```

Then add the customized `dogu.json` to your registry

**`Dockerfile`**

Add these lines to the `Dockerfile` in the final stage, f. i. near the start `CMD`:

```dockerfile
# ...rest of the Dockerfile

ENV SERVICE_8080_TAGS="webapp" \
    SERVICE_8080_NAME="sonar"

CMD ["/startup.sh"]
```

These lines manage to configure the right `services` keys in the CES registry so that nginx will produce a proper route
to `/sonar`. Otherwise, the both exposed ports (application and delve) would be routed like `/sonar-8080` which does not
work out on any level.

```shell
cd /vagrant/containers/sonar # or whereever your sonarqube repo is located at
cesapp build . && cesapp start sonar
```

Then disable the VM's firewall so the port can be actually connected.
```shell
sudo ufw disable
```

`cesapp` does not handle the necessary environment variable `STAGE=debug` at all but the variable is needed to build 
that image to run `dlv`. Let's replace the dogu image with one that contains the `dlv`-enabled build with these two 
calls from inside the CES-VM:

```shell
make docker-build
cesapp recreate --start sonar
```

As above for the Multinode installation, the dogu will not get healthy until you connect your debugger with `dlv`. Point
your debugger at the outer VM IP address at port 2345 (f. i. `192.168.56.2:2345`)  

**BE SURE TO CLEAN UP THIS BEFORE COMMITTING**

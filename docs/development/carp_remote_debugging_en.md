# CARP Remote Debugging

With sonarcarp it is possible to debug the carp while running within an existing ecosystem to facilitate the analysis 
of specific behaviors.

# Enable Remote Debugging

In order to enable remote debugging for sonarcap you need to adjust your `.env` file by adding the line:

```
DEBUG=true
```

This creates a new sonar image that contains [Delve](https://github.com/go-delve/delve/tree/master) and starts sonarcarp
with `delve`, which waits for a remote debugging session on port `2345`.

# Port Forwarding for Debugging-Port

To access the remote debugging port, we still need to forward the port to become accessible by the remote debuger.

## CES-Multinode

To debug the sonarcarp in CES Multinode, you only need to create a port forward for port 2345 to the Sonar pod.
The port forward can be created with kubectl or with k9s.

```shell
kubectl port-forward sonar-6d7b47cd7b-pqprr 2345:2345
```

The remote debugger can then connect to `localhost:2345`.
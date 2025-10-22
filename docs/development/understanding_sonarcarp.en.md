# Understanding how Sonarcarp works

## General workflows in Sonarcarp

### Log in

With SonarQube 2025, the Sonar CAS plugin had to be replaced by a CAS Authentication Reverse Proxy (CARP) due to 
inadequate support.

When Dogu starts, SonarQube startup parameters are first rendered into the CARP configuration file. Sonarcarp then uses this command to run SonarQube in order to avoid multiple main processes in the container (and thus, for example, problems arising when stopping containers).

This Sonarcarp is located at the exposed port of the SonarQube container and, like a machine-in-the-middle, intercepts 
all requests and first compares them with the started SonarQube server. This is done because SonarQube allows internal 
user accounts (as opposed to external accounts, i.e., from CAS/LDAP), whose query in CAS could lead to unnecessary 
throttling. If the request has not yet been authenticated to an internal/external user account, the request is rejected 
by SonarQube with HTTP401. Sonarcarp's own configurable throttling mechanism ensures a temporary reduction in the attack
surface (when a threshold value is exceeded). Sonarcarp recognizes the HTTP401 result and redirects to the CAS login. 
After a successful login, a CAS cookie is first issued. However, this is recognized in a new run (see above) and the 
request is copied to SonarQube and provided with special authentication headers that indicate external authentication to
SonarQube. SonarQube's response is then reflected back to the original request (the one after the CAS login).

### Frontchannel logout

It is worth noting that logout calls must not be subject to session inspection. This means that even unauthenticated users should be able to call the logout endpoints listed below.

SonarQube session cookies are required to perform a front channel. These are stored at runtime so that they can be used in the event of a back channel logout. After use, they are deleted from memory. Front channel logouts also take place artificially during back channel logouts.

Front channel logout currently works as follows:

1. The user clicks on the logout navigation item
2. This leads to a request to the `/sonar/sessions/logout` endpoint
3. This leads to a request to the `/sonar/api/authentication/logout` endpoint
4. Sonarcarp receives this call:
   - Initially does NOT execute this request against SonarQube
   - Redirects to the CAS logout, which performs a backchannel logout for all registered services (including SonarQube).
5. This is followed by a backchannel logout, which Sonarcarp receives and cleans up its own state (see below)

### Backchannel Log-out 

Backchannel logout currently works as follows:

1. The user logs out of another service (or by clicking the logout link in the Warp menu)
2. This triggers a POST request from CAS to `/sonar/`
3. Sonarcarp receives this call:
   - Sonarcarp performs an artificial front channel logout via request (including session and XSRF tokens) to SonarQube
   - SonarcarprRedirects to the CAS logout, which performs a backchannel logout to all other services
      - No recursion is achieved here, as CAS knows from the CAS session that it does not need to perform any further logouts
4. Sonarcarp cleans up the session map from the current account-to-cookie mapping.

## Filters

Processes related to authentication are often complex. In order to separate and simplify the processing of different 
aspects, similar procedures have been outsourced to different filters. A filter should ideally only handle one part of 
the process.

These filters are nested within each other to form a filter chain. Requests must pass through all of these filters in 
sequence for successful processing (the carp server part is responsible for the chaining, in reverse order):

```
Client
⬇️     ⬆️
logHandler (logs if necessary)
⬇️     ⬆️
backchannelLogoutHandler (detects and handles backchannel logout)
⬇️     ⬆️
throttlingHandler (detects HTTP401 and handles client requests through throttling) 
⬇️     ⬆️
casHandler (distinguishes between REST and browser requests, checks requests against CAS)
⬇️     ⬆️
proxyHandler (handles remaining authentication parts and implementation of request/response proxying)
⬇️     ⬆️
SonarQube
```

At each filter stage, there is the potential for an interruption in the chain (usually due to rejection of the request).

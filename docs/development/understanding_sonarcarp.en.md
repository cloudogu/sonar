# Understanding how Sonarcarp works

## General workflows in Sonarcarp

### Log in

With SonarQube 2025, the Sonar CAS plugin had to be replaced by a CAS Authentication Reverse Proxy (CARP) due to 
inadequate support.

This Sonarcarp is located at the exposed port of the SonarQube container and, like a machine-in-the-middle, intercepts 
all requests and first compares them with the started SonarQube server. This is done because SonarQube allows internal 
user accounts (as opposed to external accounts, i.e., from CAS/LDAP), whose query in CAS could lead to unnecessary 
throttling. If the request has not yet been authenticated to an internal/external user account, the request is rejected 
by SonarQube with HTTP401. Sonarcarp's own configurable throttling mechanism ensures a temporary reduction in the attack
surface (when a threshold value is exceeded). Sonarcarp recognizes the HTTP401 result and redirects to the CAS login. 
After a successful login, a CAS cookie is first issued. However, this is recognized in a new run (see above) and the 
request is copied to SonarQube and provided with special authentication headers that indicate external authentication to
SonarQube. SonarQube's response is then reflected back to the original request (the one after the CAS login).

### Frontchannel Log-out

tbd

### Backchannel Log-out 

tbd

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

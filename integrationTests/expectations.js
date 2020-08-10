
const config = require('./config');

exports.expectStateUser = function(user) {
    console.log("user:");
    console.log(user);
    console.log("config:");
    console.log(config);
    console.log("expect login");
    expect(user.login).toBe(config.username);
    console.log("expect email");
    expect(user.email).toBe(config.email);
    console.log("expect displayName");
    expect(user.name).toBe(config.displayName);
    console.log("expect username");
    expect(user.externalIdentity).toBe(config.username);
}

exports.expectStateAdmin = function(user) {
    const groups = user.groups;
    expect(user.login).toBe(config.username);
    expect(groups).toContain(config.adminGroup);
}

exports.expectCasLogin = function(url) {
    expect(url).toBe(config.baseUrl + '/cas/login?service=https://'+config.fqdn+'/sonar/sessions/init/cas');
}

exports.expectCasLogout = function(url) {
    expect(url).toBe(config.baseUrl + '/cas/logout');
}

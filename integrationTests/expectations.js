
const config = require('./config');

exports.expectStateUser = function(user) {
    expect(user.login).toBe(config.username);
    expect(user.email).toBe(config.email);
    expect(user.name).toBe(config.displayName);
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
    expect(url).toBe(config.baseUrl + '/cas/logout?service=https%3A%2F%2F'+config.fqdn+'%2Fsonar');
}
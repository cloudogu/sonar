
const config = require('./config');

exports.expectState = function(state) {
    const user = state.user;
    expect(user.login).toBe(config.username);
    expect(user.firstname).toBe(config.firstname);
    expect(user.lastname).toBe(config.lastname);
    expect(user.mail).toBe(config.email);

}

exports.expectCasLogin = function(url) {
    expect(url).toBe(config.baseUrl + '/cas/login?TARGET=https%3A%2F%2F192.168.56.2%2Fsonar%2Fcas%2Fvalidate');
}

exports.expectCasLogout = function(url) {
    expect(url).toBe(config.baseUrl + '/cas/logout?service=https%3A%2F%2F192.168.56.2%2Fsonar');
}
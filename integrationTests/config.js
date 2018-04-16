let cesFqdn = process.env.CES_FQDN;
if (!cesFqdn) {
  // url from ecosystem with private network
  cesFqdn = "192.168.42.2"
}

let webdriverType = process.env.WEBDRIVER;
if (!webdriverType) {
  webdriverType = 'local';
}

module.exports = {
    fqdn: cesFqdn,
    baseUrl: 'https://' + cesFqdn,
    jenkinsContextPath: '/sonar',
    username: 'ces-admin',
    password: 'ecosystem2016',
    firstname:'admin',
    lastname: 'admin',
    displayName: 'ces-admin',
    email: 'ces-admin@cloudogu.com',
    webdriverType: webdriverType,
    debug: true,
    adminGroup: 'CesAdministrators',
	testToken: 'testToken'
};
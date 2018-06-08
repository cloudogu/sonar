let cesFqdn = process.env.CES_FQDN;
if (!cesFqdn) {
  // url from ecosystem with private network
  cesFqdn = "192.168.56.2"
}

let webdriverType = process.env.WEBDRIVER;
if (!webdriverType) {
  webdriverType = 'local';
}

module.exports = {
    fqdn: cesFqdn,
    baseUrl: 'https://' + cesFqdn,
    sonarContextPath: '/sonar',
    username: 'cwolfes',
    password: 'Trio-123',
    firstname:'Christoph',
    lastname: 'Wolfes',
    displayName: 'cwolfes',
    email: 'cwolfes@triology.de',
    webdriverType: webdriverType,
    debug: true,
    adminGroup: 'Ces-Admin',
	sonarqubeToken: 'blabla'
};

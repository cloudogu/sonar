const env = require("@cloudogu/dogu-integration-test-library/lib/environment_variables");


/**
 * Sends a GET request to the SonarQube API endpoint and checks the response status code
 * @param {String} APIEndpoint - The API endpoint, appended to "https://FQDN/sonar/api"
 * @param {String} username - The username or token
 * @param {String} password - The password for the user. Can be left empty if token is used for username.  Default: empty
 * @param {boolean} failOnStatusCode - Set to "false" to not make this command fail on response codes other than 2xx and 3xx.  Default: false
 * @param {number} expectedResponseStatusCode - The status code you expect the request to respond with.  Default: 200
 * @param {String} method - The request method, e.g. GET or POST. Default: GET
 */
const requestSonarAPI = (APIEndpoint, username, password= "", failOnStatusCode = true, expectedResponseStatusCode = 200, method = "GET") => {
    cy.request({
        method: method,
        url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api" + APIEndpoint,
        auth: {
            'user': username,
            'pass': password
        },
        failOnStatusCode: failOnStatusCode
    }).then((response) => {
        expect(response.status).to.eq(expectedResponseStatusCode)
        return response
    })
}

module.exports.register = function () {
    Cypress.Commands.add("requestSonarAPI", requestSonarAPI)
}
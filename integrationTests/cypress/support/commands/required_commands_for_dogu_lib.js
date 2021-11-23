const env = require("@cloudogu/dogu-integration-test-library/lib/environment_variables");
/**
 * Deletes a user from the dogu via an API call.
 * @param {String} username - The username of the user.
 * @param {boolean} exitOnFail - Determines whether the test should fail when the request did not succeed. Default: false
 */
const deleteUserFromDoguViaAPI = (username, exitOnFail = false) => {
    cy.clearCookies()
    cy.request({
        method: "POST",
        url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api/users/deactivate?login=" + username,
        auth: {
            'user': env.GetAdminUsername(),
            'pass': env.GetAdminPassword()
        },
        failOnStatusCode: exitOnFail
    })
}

// Implement the necessary commands for the dogu integration test library
Cypress.Commands.add("deleteUserFromDoguViaAPI", deleteUserFromDoguViaAPI)
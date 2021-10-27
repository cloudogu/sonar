/**
 * Deletes a user from the dogu via an API call.
 * @param {String} username - The username of the user.
 * @param {boolean} exitOnFail - Determines whether the test should fail when the request did not succeed. Default: false
 */
 const deleteUserFromDoguViaAPI = (username, exitOnFail = false) => {
    // TODO: Lösche den internen Nutzer in dem zu testenden Dogu
/*     cy.request({
        method: "POST",
        url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api/users/deactivate",
        body: {
            'login': username
        },
        auth: {
            user: env.GetAdminUsername(),
            pass: env.GetAdminPassword(),
          },
        failOnStatusCode: false,
        timeout: 1000,
    }).then((response) => {
        // 2xx and 3xx responses show that the request succeeded
        if (response.status <= 400) {
            return true;
        } else {
            return false;
        }
    }) */

}

// Implement the necessary commands for the dogu integration test library
Cypress.Commands.add("deleteUserFromDoguViaAPI", deleteUserFromDoguViaAPI)
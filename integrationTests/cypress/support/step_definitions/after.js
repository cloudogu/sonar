const {After} = require("@badeball/cypress-cucumber-preprocessor");
const env = require("@cloudogu/dogu-integration-test-library/lib/environment_variables");

After({tags: "@requires_api_token_to_be_removed_afterwards"}, () => {
    cy.fixture("testuser_data").then(function (testuserdata) {
        cy.clearCookies()
        cy.request({
            method: "POST",
            url: Cypress.config().baseUrl + "/" + env.GetDoguName() + "/api/user_tokens/revoke?name=" + testuserdata.sonarqubeToken + "&login=" + testuserdata.username,
            auth: {
                'user': env.GetAdminUsername(),
                'pass': env.GetAdminPassword()
            }
        }).then((response) => {
            expect(response.status).to.eq(204)
            cy.wait(30000)
        })
    })
});

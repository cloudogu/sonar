const {
    Given
} = require("@badeball/cypress-cucumber-preprocessor");
const env = require("@cloudogu/dogu-integration-test-library/lib/environment_variables");

/**
 * Make sure that the API Token is set
 */
Given(/^check if API token is set$/, function () {
    cy.task("getAPIToken").then((token) => {
        if (token === "") {
            generateToken()
        }
    })
});

/**
 * always set new API-Token
 */
Given(/^reset API token$/, function () {
    generateToken()
});

// Replace UI-driven generateToken() with an API-driven version
function generateToken() {
  const name = Math.random().toString();
  cy.task("getAPIToken").then((adminToken) => {
    // optionally revoke existing token(s) first:
    // cy.requestSonarAPI(`/user_tokens/revoke?name=${encodeURIComponent('your-name')}`, adminToken, true, 204, "POST");
    cy.requestSonarAPI(`/user_tokens/generate?name=${encodeURIComponent(name)}`, adminToken, true, 200, "POST")
      .then((response) => {
        // SonarQube returns the token in JSON; store it directly
        cy.task("setAPIToken", response.body.token);
      });
  });
}



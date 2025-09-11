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

function generateToken() {
  cy.visit("/" + env.GetDoguName() + "/account/security");

  cy.get('#token-name', { timeout: 10000 }).should('be.visible')
    .clear().type(Math.random().toString(), { force: true });

  cy.contains('div', 'Select Token Type', { timeout: 10000 }).click({ force: true });
  cy.contains('#react-select-2-listbox [role="option"]', 'User Token', { timeout: 10000 }).click({ force: true });

  cy.intercept('POST', '**/api/user_tokens/generate**').as('genToken');
  cy.contains('button', 'Generate', { timeout: 10000 }).click({ force: true });

  cy.wait('@genToken').its('response.statusCode').should('be.oneOf', [200, 201]);

  // Be flexible on where/how the token is rendered:
  cy.get('body', { timeout: 10000 }).then($body => {
    // try common containers in order
    const selectors = ['code', 'pre code', '.token-output code', '[data-testid="generated-token"]'];
    let found = null;
    for (const sel of selectors) {
      const el = $body.find(sel);
      if (el.length) { found = el; break; }
    }
    if (!found) {
      // surface the page content to debug selector drift
      throw new Error('Generated token element not found. The UI may have changed.');
    }
    cy.task("setAPIToken", Cypress.$(found).text().trim());
  });
}


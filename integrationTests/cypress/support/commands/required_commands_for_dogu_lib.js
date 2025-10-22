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

function closePromoDialog() {
  cy.get('body').then(($body) => {
    const $dialog = $body.find('.it__promotion_notification');
    if ($dialog.length) {
      cy.task('log', 'Promo dialog detected, closing it');

      // click the Dismiss button inside the dialog
      cy.wrap($dialog).within(() => {
        cy.contains('button', 'Dismiss', { matchCase: false }).click({ force: true });
        // alternative: cy.get('button.sw-justify-center').click({ force: true })
      });
    } else {
      cy.task('log', 'No Promo dialog visible');
    }
  });
}

function closeSonarWelcomeDialog() {
  cy.get('body').then($body => {
    if ($body.find('div[role="dialog"]').length) {
      cy.task('log','Sonar welcome dialog detected, closing it');
      cy.get('button[aria-label="Close"]').click({ force: true });
    }
    else {
      cy.task('log','No Sonar welcome dialog visible');
    }
  });
};

const closeDialogs = () => {
    cy.wait(1000)
    closeSonarWelcomeDialog();
    closePromoDialog();
};

// Implement the necessary commands for the dogu integration test library
Cypress.Commands.add("deleteUserFromDoguViaAPI", deleteUserFromDoguViaAPI)
Cypress.Commands.add("closeDialogs", closeDialogs)
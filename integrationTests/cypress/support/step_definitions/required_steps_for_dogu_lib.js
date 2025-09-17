const {When, Then} = require("@badeball/cypress-cucumber-preprocessor");

// Loads all steps from the dogu integration library into this project
const doguTestLibrary = require('@cloudogu/dogu-integration-test-library')
const env = require('@cloudogu/dogu-integration-test-library/lib/environment_variables')
doguTestLibrary.registerSteps()


When(/^the user clicks the dogu logout button$/, function () {
    // cy.visit("/" + env.GetDoguName(), { failOnStatusCode: false })
    // // wait until the logoutMenuHandler is injected
    // // see https://github.com/cloudogu/sonar-cas-plugin/blob/develop/src/main/java/org/sonar/plugins/cas/logout/CasSonarSignOutInjectorFilter.java#L132
    // cy.wait(1000)
    // // Click user menu button
    // cy.get('#userAccountMenuDropdown-trigger').scrollIntoView().click();
    // // Click logout button
    // cy.contains("Log out").click();



  const dogu = env.GetDoguName();
  const triggerSel = '#userAccountMenuDropdown-trigger[aria-haspopup="menu"]';
  const menuSel = '#userAccountMenuDropdown-dropdown';

  // Go to the dogu root (CAS plugin injects logout handler there)
  cy.visit(`/${dogu}`, { failOnStatusCode: false });
  cy.screenshot('click-logout-before', { capture: 'viewport' });
  cy.closeDialogs();
  // Wait for the account button to exist instead of a blind sleep
  cy.screenshot('click-logout-dialog', { capture: 'viewport' });

  cy.get(triggerSel, { timeout: 15000 }).should('be.visible');
  // Open the dropdown (click twice is harmless with Radix)
  cy.get(triggerSel).click({ force: true });
  cy.screenshot('click-logout-trigger', { capture: 'viewport' });

  // Wait for Radix menu to be open & visible
  cy.get(menuSel, { timeout: 10000 })
    .should('have.attr', 'data-state', 'open')
    .and('be.visible');

  // Click "Log out" inside the dropdown (scoped)
  cy.get(menuSel).within(() => {
    cy.contains('a[role="menuitem"]', /^log out$/i, { timeout: 10000 })
      .scrollIntoView()
      .click({ force: true });
  });

  cy.screenshot('click-logout-menu', { capture: 'viewport' });

  // Clean up any leftovers
  cy.clearCookies();
});


Then(/^the user has administrator privileges in the dogu$/, function () {
    cy.visit("/" + env.GetDoguName(), { failOnStatusCode: false })
    cy.get('#global-navigation').contains("Administration")
});

Then(/^the user has no administrator privileges in the dogu$/, function () {
    cy.visit("/" + env.GetDoguName(), { failOnStatusCode: false })
    cy.get('#global-navigation').contains("Administration").should('not.exist')
});

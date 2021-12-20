// Loads all steps from the dogu integration library into this project
const doguTestLibrary = require('@cloudogu/dogu-integration-test-library')
const env = require('@cloudogu/dogu-integration-test-library/lib/environment_variables')
doguTestLibrary.registerSteps()

When(/^the user clicks the dogu logout button$/, function () {
    cy.visit("/" + env.GetDoguName(), { failOnStatusCode: false })
    // wait until the logoutMenuHandler is injected
    // see https://github.com/cloudogu/sonar-cas-plugin/blob/develop/src/main/java/org/sonar/plugins/cas/logout/CasSonarSignOutInjectorFilter.java#L132
    cy.wait(1000)
    // Click user menu button
    cy.get('*[class^="dropdown-toggle navbar-avatar"]').scrollIntoView().click();
    // Click logout button
    cy.get('*[class^="popup is-bottom"]').contains("Log out").click();
});

Then(/^the user has administrator privileges in the dogu$/, function () {
    cy.visit("/" + env.GetDoguName(), { failOnStatusCode: false })
    cy.get('*[class^="global-navbar-menu"]').contains("Administration")
});

Then(/^the user has no administrator privileges in the dogu$/, function () {
    cy.visit("/" + env.GetDoguName(), { failOnStatusCode: false })
    cy.get('*[class^="global-navbar-menu"]').contains("Administration").should('not.exist')
});

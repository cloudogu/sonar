Feature: API-based CAS login and logout functionality

  @requires_testuser
  Scenario: user can access the API with username and password
    Given the user is logged out of the CES
    Then the user can access the SonarQube API with username and password

  @requires_testuser
  Scenario: user can not access the API with wrong username and password
    Given the user is logged out of the CES
    Then the user can not access the SonarQube API with wrong username and password

  @requires_testuser
  @requires_api_token_to_be_removed_afterwards
  Scenario: API authentication with User Token
    Given the user is member of the admin user group
    When the user creates a User Token via the Web API
    Then the user can access the Web API with the User Token

  @requires_testuser
  Scenario: /users API responds with correct user attributes
    When the user's attributes are requested via Web API
    Then the user's attributes are matching those in the user backend

  Scenario: /users API's respond contains admin group for admin user
    When the admin user's attributes are requested via Web API
    Then the user's attributes should include the admin group

  @requires_testuser
  Scenario: testUser has admin privileges if added to admin group in usermgt (via usermgt api)
    Given the user is member of the admin user group
    Then the user can access the /users/groups Web API endpoint

  @requires_testuser
  Scenario: test user has no admin privileges
    Then the user can not access the /users/groups Web API endpoint

  @requires_testuser
  Scenario: user loses admin permissions if removed from admin group
    Given the user is member of the admin user group
    And the user is logged into the CES
    When the user logs out by visiting the cas logout page
    And the user is removed as a member from the CES admin group
    And the user logs into the CES
    And the user logs out by visiting the cas logout page
    Then the user can not access the /users/groups Web API endpoint


Feature: API-based CAS login and logout functionality

  @requires_testuser
  Scenario: user can access the API with API token
    Given the user is logged out of the CES
    When the test user logs in with correct credentials
    Given check if API token is set
    Then the user can access the SonarQube API with API token

  @requires_testuser
  Scenario: user can not access the API with wrong api token
    Given the user is logged out of the CES
    Then the user can not access the SonarQube API with wrong api token

  @requires_testuser
  # @requires_api_token_to_be_removed_afterwards
  Scenario: API authentication with User Token
    Given the user is member of the admin user group
    When the user creates a User Token via the Web API
    Then the user can access the Web API with the User Token

  @requires_testuser
  Scenario: /users API responds with correct user attributes
    When the user requests his/her attributes via the /users API endpoint
    Then the user's login attribute matches the username attribute in the user backend
    And the user's name attribute matches the displayName attribute in the user backend
    And the user's email attribute matches the mail attribute in the user backend
    And the user's externalIdentity attribute matches the username attribute in the user backend

  @requires_testuser
  Scenario: test user has no admin privileges
    Then the user can not access the /users/groups Web API endpoint

  @requires_testuser
  Scenario: testUser has admin privileges if added to admin group in usermgt (via usermgt api)
    Given the user is member of the admin user group
    And the user is logged into the CES
    Then the user can access the /users/groups Web API endpoint

  @requires_testuser
  Scenario: user loses admin permissions if removed from admin group
    Given the user is member of the admin user group
    And the user is logged into the CES
    And wait for sonar load
    When the user logs out by visiting the cas logout page
    When the user is removed as a member from the CES admin group
    Given the user is logged into the CES
    And wait for sonar load
    And the user logs out by visiting the cas logout page
    Then the user can not access the /users/groups Web API endpoint

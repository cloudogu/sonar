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
    When the user can create a User Token via the Web API
    Then the user can access the Web API with the User Token

  @requires_testuser
  Scenario: rest - check user attributes
    Given I would have implemented this test

  @requires_testuser
  Scenario: rest - admin user is in admin group
    Given I would have implemented this test

  @requires_testuser
  Scenario: rest - user (testUser) has admin privileges if added to admin group in usermgt (via usermgt api)
    Given I would have implemented this test

  @requires_testuser
  Scenario: rest - user (testUser) has no admin privileges
    Given I would have implemented this test

  @requires_testuser
  Scenario: rest - user (testUser) remove admin privileges
    Given I would have implemented this test
   #give user admin permissions in usermgt
   #log user in and out
   #make sure user is logged out (=> .../cas/logout is shown)
   #take admin permissions from user in usermgt
   #log user in and out
   #make sure user is logged out (=> .../cas/logout is shown)
   #check that user has no access to restricted api endpoints

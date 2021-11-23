Feature: CAS user data replication

  @requires_testuser
  Scenario: test user data is replicated in SonarQube
    Given the user is logged into the CES
    When the user opens the dogu start page
    And the user clicks the user menu button
    And the user clicks the My Account button
    Then the user is redirected to the account site
    And the page shows the replicated data of the user in tabular form
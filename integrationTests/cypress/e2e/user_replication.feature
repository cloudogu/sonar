Feature: CAS user data replication

  @requires_testuser
  Scenario: test user data is replicated in SonarQube
    Given the user is logged into the CES
    When the user navigates to "/account" page
    Then the page shows the replicated data of the user in tabular form
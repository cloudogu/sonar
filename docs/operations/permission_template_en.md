# Permission template

The permission template is a mechanism in SonarQube to set up *project permissions*. The default template will be changed
during the dogu startup to ensure that the CES_ADMIN group has access to administer new created projects. The following
permissions will be set (admin codeviewer issueadmin securityhotspotadmin scan user ) this setup can be verified
(`Administration -> Security -> Permisssion Templates`). *see setup.json for further details*

![default template overview](figures/default_template_ces_admin_permissions.png)


The permissions for projects created without correct CES_ADMIN group permissions can be changed later using a specific config-key.
(set `amend_projects_with_ces_admin_permissions` to `all` -> restart sonar -> CES_ADMIN group will be added to all projects).
The implementation uses the SonarQube API endpoint `permissions/add_group`. After the changes to the projects are applied the config-key
will automatically reset to `none` (see config-key description in dogu.json). 

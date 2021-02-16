# Permission Template

The permission template is a mechanism in SonarQube to setup project permissions. The default template will be changed
during the dogu startup to ensure that the CES_ADMIN group has access to administer new created projects. The following
permissions will be set (admin codeviewer issueadmin securityhotspotadmin scan user ) this setup can be verified
(Administration -> Security -> Permisssion Templates). *see setup.json for further details*

![default template overview][assets/default_template_ces_admin_permissions.png]

Apart from project permissions there are some global permission, these permission will be set up during
start up as well. Defined global permissions for the CES_ADMIN group will be (admin profileadmin gateadmin provisioning)

The permissions for projects created without correct CES_ADMIN group permissions can be changed later using a specific etdkey.
(set `amend_projects_with_ces_admin_permissions` to `all` -> restart sonar -> CES_ADMIN group will be added to all projects).
The Implementation uses the sonar api endpoint `permissions/add_group`.

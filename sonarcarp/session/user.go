package session

// User contains information about an internal SonarQube account or a CAS SSO account.
type User struct {
	UserName string
	// UidSub contains the user internal sonarqube ID as fetched from the JWT token.
	UidSub string
}

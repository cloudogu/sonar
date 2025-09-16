package session

import "fmt"

// User contains information about an internal SonarQube account or a CAS SSO account.
type User struct {
	// UserName contains the CAS username
	UserName string
	// JwtToken contains the user's sonarqube session. This will be used during CAS backchannel logout request as there
	// is no other information to handle this
	JwtToken string
}

func (u *User) isNullUser() bool {
	return *u == nullUser
}

// String returns a printable representation of a user and their sonarqube session token
func (u *User) String() string {
	if u.isNullUser() {
		return "null"
	}
	const cryptoHeaderLength = 21
	printingSaveToken := string([]byte(u.JwtToken)[cryptoHeaderLength : cryptoHeaderLength+32])
	return fmt.Sprintf("%s:%s...", u.UserName, printingSaveToken)
}

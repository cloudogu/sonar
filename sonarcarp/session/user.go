package session

import "fmt"

// User contains information about an internal SonarQube account or a CAS SSO account.
type User struct {
	// UserName contains the CAS username
	UserName string
	// JwtToken contains the user's sonarqube session. This will be used during CAS backchannel logout request as there
	// is no other information to handle this.
	// It complements the XsrfToken for this purpose.
	JwtToken string
	// XsrfToken contains the user's cross site req forgery token as fetched while being logged-in.
	// This token will be used to orderly log out the user against the sonarqube authentication API. It complements the
	// JwtToken for this purpose.
	XsrfToken string
}

// String returns a printable representation of a user and their sonarqube session token
func (u *User) String() string {
	if u.isNullUser() {
		return "null : null"
	}
	const cryptoHeaderLength = 21
	// hide useless crypto algo header and cut the jwt just so some changes can be seen but not the whole thing
	// to avoid data security inflictions.
	printingSaveToken := string([]byte(u.JwtToken)[cryptoHeaderLength : cryptoHeaderLength+32])
	return fmt.Sprintf("%s : %s...", u.UserName, printingSaveToken)
}

func (u *User) isNullUser() bool {
	return *u == nullUser
}

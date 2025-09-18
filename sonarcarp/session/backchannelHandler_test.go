package session

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
)

const testSamlLogoutMessage = `<samlp:LogoutRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" ID="LR-18-0Gq9gtdqUocxj5jbhhafkHQE" Version="2.0" IssueInstant="2025-09-18T11:33:41Z"><saml:NameID xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">username</saml:NameID><samlp:SessionIndex>ST-18-HdnrDDK-phvPpNCb5sxucU2cLEg-cas</samlp:SessionIndex></samlp:LogoutRequest>`

func Test_getUserFromSamlLogout(t *testing.T) {
	tests := []struct {
		name              string
		urldecodedSamlMsg string
		want              string
		wantErr           assert.ErrorAssertionFunc
	}{
		{"return username", testSamlLogoutMessage, "username", assert.NoError},
		{"return EOF error", "", "", assert.Error},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := getUserFromSamlLogout(tt.urldecodedSamlMsg)
			if !tt.wantErr(t, err, fmt.Sprintf("getUserFromSamlLogout(%v)", tt.urldecodedSamlMsg)) {
				return
			}
			assert.Equalf(t, tt.want, got, "getUserFromSamlLogout(%v)", tt.urldecodedSamlMsg)
		})
	}
}

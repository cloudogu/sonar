package internal

import (
	"context"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetGroups(t *testing.T) {
	t.Run("group contains two elements", func(t *testing.T) {
		attr := map[string][]string{
			"groups": {"a", "b"},
		}

		u := User{
			UserName:   "",
			Attributes: attr,
		}

		groups := u.GetGroups()
		assert.Len(t, groups, 2)
		assert.Equal(t, "a", groups[0])
		assert.Equal(t, "b", groups[1])
	})

	t.Run("group is empty", func(t *testing.T) {
		attr := map[string][]string{
			"groups": {},
		}

		u := User{
			UserName:   "",
			Attributes: attr,
		}

		groups := u.GetGroups()
		assert.Len(t, groups, 0)
	})

	t.Run("group key does not exist", func(t *testing.T) {
		attr := map[string][]string{}

		u := User{
			UserName:   "",
			Attributes: attr,
		}

		groups := u.GetGroups()
		assert.Len(t, groups, 0)
	})
}

func TestGetDisplayName(t *testing.T) {
	t.Run("single displayName", func(t *testing.T) {
		u := createUser(map[string][]string{
			"displayName": {"a"},
		})

		dn := u.GetDisplayName()
		assert.Equal(t, "a", dn)
	})

	t.Run("multiple displayNames", func(t *testing.T) {
		u := createUser(map[string][]string{
			"displayName": {"a", "b"},
		})

		dn := u.GetDisplayName()
		assert.Equal(t, "a", dn)
	})

	t.Run("empty displayName", func(t *testing.T) {
		u := createUser(map[string][]string{
			"displayName": {},
		})

		dn := u.GetDisplayName()
		assert.Equal(t, "", dn)
	})

	t.Run("key displayName does not exists", func(t *testing.T) {
		u := createUser(map[string][]string{})

		dn := u.GetDisplayName()
		assert.Equal(t, "", dn)
	})
}

func TestGetMail(t *testing.T) {
	t.Run("single mail address", func(t *testing.T) {
		u := createUser(map[string][]string{
			"mail": {"a"},
		})

		dn := u.GetMail()
		assert.Equal(t, "a", dn)
	})

	t.Run("multiple mail addresses", func(t *testing.T) {
		u := createUser(map[string][]string{
			"mail": {"a", "b"},
		})

		dn := u.GetMail()
		assert.Equal(t, "a", dn)
	})

	t.Run("empty mail address", func(t *testing.T) {
		u := createUser(map[string][]string{
			"mail": {},
		})

		dn := u.GetDisplayName()
		assert.Equal(t, "", dn)
	})

	t.Run("key mail does not exists", func(t *testing.T) {
		u := createUser(map[string][]string{})

		dn := u.GetMail()
		assert.Equal(t, "", dn)
	})
}

func createUser(attributes map[string][]string) User {
	u := User{
		UserName:   "TestUser",
		Attributes: attributes,
	}

	return u
}

func TestWithUser(t *testing.T) {
	u := User{
		UserName: "testUser",
		Attributes: map[string][]string{
			"mail":   {"a"},
			"groups": {"a", "b"},
		}}

	ctx := WithUser(context.TODO(), u)

	user := ctx.Value(userKey)
	assert.NotNil(t, user)

	userValue, ok := user.(User)
	assert.True(t, ok)
	assert.Equal(t, u, userValue)
}

func TestGetUser(t *testing.T) {
	t.Run("user found in context", func(t *testing.T) {
		u := User{
			UserName: "testUser",
			Attributes: map[string][]string{
				"mail":   {"a"},
				"groups": {"a", "b"},
			}}

		ctx := context.WithValue(context.TODO(), userKey, u)

		user, ok := GetUser(ctx)
		assert.True(t, ok)
		assert.Equal(t, u, user)
	})

	t.Run("no user in context", func(t *testing.T) {
		_, ok := GetUser(context.TODO())
		assert.False(t, ok)
	})
}

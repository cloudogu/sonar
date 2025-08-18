package internal

import (
	"context"
)

type Role string

type userContextKey int

const (
	userKey userContextKey = iota
)

type UserAttributes map[string][]string

type User struct {
	UserName   string
	Replicate  bool
	Attributes UserAttributes
}

func (u User) GetGroups() []string {
	return u.Attributes["groups"]
}

func (u User) GetDisplayName() string {
	return u.getFirstAttributeOrEmptyString("displayName")
}

func (u User) GetMail() string {
	return u.getFirstAttributeOrEmptyString("mail")
}

func (u User) getFirstAttributeOrEmptyString(key string) string {
	attributeList, ok := u.Attributes[key]
	if !ok {
		return ""
	}

	if len(attributeList) == 0 {
		return ""
	}

	return attributeList[0]
}

func WithUser(ctx context.Context, user User) context.Context {
	return context.WithValue(ctx, userKey, user)
}

func GetUser(ctx context.Context) (User, bool) {
	u, ok := ctx.Value(userKey).(User)
	if !ok {
		return User{}, false
	}

	return u, true
}

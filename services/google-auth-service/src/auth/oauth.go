package auth

import (
	"context"
	"os"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

var OAuthConfig = &oauth2.Config{
	ClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
	ClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
	RedirectURL:  getOAuthRedirectURL(),
	Scopes:       []string{"https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/userinfo.profile", "https://www.googleapis.com/auth/userinfo.email"},
	Endpoint:     google.Endpoint,
}

func getOAuthRedirectURL() string {

	if os.Getenv("K_SERVICE") != "" {
		return "https://google-auth-service-656120491361.africa-south1.run.app/callback"
	}

	return "http://localhost:8080/callback"
}

func OAuthURL(state string) string {
	return OAuthConfig.AuthCodeURL(state, oauth2.AccessTypeOffline, oauth2.ApprovalForce)
}

func ExchangeCode(code string) (*oauth2.Token, error) {
	return OAuthConfig.Exchange(context.TODO(), code)
}

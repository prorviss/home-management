package auth

import (
	"context"
	"fmt"
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
		region := "africa-south1"
		serviceName := os.Getenv("K_SERVICE")
		return fmt.Sprintf("https://%s.%s.run.app", serviceName, region)
	}

	return "http://localhost:8080"
}

func OAuthURL(state string) string {
	return OAuthConfig.AuthCodeURL(state, oauth2.AccessTypeOffline, oauth2.ApprovalForce)
}

func ExchangeCode(code string) (*oauth2.Token, error) {
	return OAuthConfig.Exchange(context.TODO(), code)
}

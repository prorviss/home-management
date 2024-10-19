package handlers

import (
	"context"
	"net/http"
	"orviss.co.za/google-auth-service/auth"
	"orviss.co.za/google-auth-service/firestore"
	"log"
)

// HandleHome redirects the user to the login page.
func HandleHome(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "/login", http.StatusTemporaryRedirect)
}

// HandleLogin starts the OAuth2 flow by redirecting the user to the Google OAuth URL.
func HandleLogin(w http.ResponseWriter, r *http.Request) {
	url := auth.OAuthURL("state-token")
	http.Redirect(w, r, url, http.StatusTemporaryRedirect)
}

func HandleCallback(client *firestore.Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()

		code := r.URL.Query().Get("code")
		token, err := auth.ExchangeCode(code)
		if err != nil {
			w.Write([]byte(err.Error()))
			return
		}

		// Get user email
		email, err := auth.GetUserEmail(token)
		if err != nil {
			w.Write([]byte("Failed to get user email: " + err.Error()))
			return
		}

		// Store token in Firestore using the user's email as the document ID
		err = client.StoreToken(ctx, email, token)
		if err != nil {
			log.Fatalf("Failed to store token: %v", err)
		}

		w.Write([]byte("Token stored for user: " + email))
	}
}
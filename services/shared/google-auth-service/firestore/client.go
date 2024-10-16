package firestore

import (
	"context"
	"log"
	"time"
	"cloud.google.com/go/firestore"
	"golang.org/x/oauth2"
)

type Client struct {
	Firestore *firestore.Client
}

func NewClient(ctx context.Context, projectID string) (*Client, error) {
	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return nil, err
	}
	return &Client{Firestore: client}, nil
}

func (c *Client) StoreToken(ctx context.Context, email string, token *oauth2.Token) error {
	_, err := c.Firestore.Collection("users").Doc(email).Set(ctx, map[string]interface{}{
		"accessToken":  token.AccessToken,
		"refreshToken": token.RefreshToken,
		"expiry":       token.Expiry.Format(time.RFC3339),
	})
	if err != nil {
		log.Fatalf("Failed to add data to Firestore: %v", err)
	}
	return err
}
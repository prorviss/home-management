package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"orviss.co.za/google-auth-service/firestore"
	"orviss.co.za/google-auth-service/handlers"
)

// Hello Again Again

func main() {

	ctx := context.Background()
	projectID := os.Getenv("GOOGLE_PROJECT_ID")
	firestoreClient, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Failed to create Firestore client: %v", err)
	}
	defer firestoreClient.Firestore.Close()

	http.HandleFunc("/", handlers.HandleHome)
	http.HandleFunc("/login", handlers.HandleLogin)
	http.HandleFunc("/callback", handlers.HandleCallback(firestoreClient))

	http.ListenAndServe(":8080", nil)

}

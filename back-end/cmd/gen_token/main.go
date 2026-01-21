package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/joho/godotenv"
)

func main() {
	// 1. Load .env file
	// Adjust path if running from root or cmd/gen_token
	// Trying to load from current dir or parent dirs
	_ = godotenv.Load()             // Ignore error if .env not found, might rely on env vars
	_ = godotenv.Load("../../.env") // Try loading from project root if running from cmd subfolder

	// 2. Get Secret
	secret := os.Getenv("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzY3ODkyNzEzLCJyb2xlIjoiYXV0aGVudGljYXRlZCIsInN1YiI6ImVjZDMxZDM5LTNjZjItNDAzNi1iMGE0LWFhOWMxNzA1MjY2NCJ9.ORjskrboXrVHNJ_1L96-k06wAOUy9K82g3pBk19S038")
	if secret == "" {
		// Fallback to the hardcoded one from previous file if env is missing, for safety/demo
		secret = "fSEoO27tLRmHAMRzDppv5apq/eOx9ki2mdCD4rDkbn9PaYz3jne699rH6/zauA9hQzcjhLbgwF3Kw08sm5vfRQ=="
		fmt.Println("Warning: SUPABASE_JWT_SECRET not found in env, using hardcoded fallback.")
	}

	// 3. Set UID (Hardcoded as per original, or could be arg)
	// Using the one from original file
	userUID := "ecd31d39-3cf2-4036-b0a4-aa9c17052664"

	claims := jwt.MapClaims{
		"sub":  userUID,
		"exp":  time.Now().Add(time.Hour * 24).Unix(),
		"aud":  "authenticated",
		"role": "authenticated",
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		log.Fatalf("Failed to sign token: %v", err)
	}

	fmt.Println("--- COPY THIS TOKEN TO POSTMAN / FLUTTER APP ---")
	fmt.Println(tokenString)
}

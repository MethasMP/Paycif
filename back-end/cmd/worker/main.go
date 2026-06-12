package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"paysif/internal/adapter/queue"
	"paysif/internal/adapter/repository"
	"paysif/internal/usecase"
	"syscall"

	_ "github.com/joho/godotenv/autoload"
)

func main() {
	// 1. Database Connection
	if err := repository.Connect(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer repository.Close()

	// Initialize SQRIL Provider and PaymentEngine (Fix 2/NewOutboxWorker signature)
	sqrilBaseURL := os.Getenv("SQRIL_BASE_URL")
	if sqrilBaseURL == "" {
		sqrilBaseURL = "https://stg-api.sqril.io"
	}
	sqrilProvider := usecase.NewSqrilProvider(
		sqrilBaseURL,
		os.Getenv("SQRIL_CLIENT_ID"),
		os.Getenv("SQRIL_CLIENT_SECRET"),
	)

	paymentEngine := usecase.NewPaymentEngine("sqril")
	paymentEngine.RegisterProvider(sqrilProvider)
	paymentEngine.RegisterProvider(&usecase.OmiseProvider{APIKey: os.Getenv("OMISE_API_KEY")})
	paymentEngine.RegisterProvider(&usecase.WiseProvider{Token: os.Getenv("WISE_API_TOKEN")})

	// 2. Worker Initialization
	w := queue.NewOutboxWorker(repository.DB, paymentEngine)

	// 3. Graceful Shutdown Context
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle OS signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// 4. Start Worker
	go w.Run(ctx)

	// Wait for signal
	sig := <-sigChan
	log.Printf("Received signal: %v. Shutting down...", sig)
	cancel()

	// Wait a bit for worker to finish (simplified)
	// In production, use WaitGroup
	log.Println("Shutdown complete.")
}

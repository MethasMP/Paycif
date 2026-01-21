package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"zappay/database"
	"zappay/internal/worker"

	_ "github.com/joho/godotenv/autoload"
)

func main() {
	// 1. Database Connection
	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	// 2. Worker Initialization
	w := worker.NewOutboxWorker(database.DB)

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

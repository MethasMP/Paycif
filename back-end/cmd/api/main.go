package main

import (
	"context"
	"log"
	"paysif/cmd/api/middleware"
	"paysif/database"
	"paysif/internal/infrastructure/redis"
	"paysif/internal/routing"
	"paysif/internal/service"

	"github.com/gin-gonic/gin"
	_ "github.com/joho/godotenv/autoload" // Optional: for local .env
)

func main() {
	// 1. Database Connection
	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()
	database.DB.SetMaxOpenConns(25)
	database.DB.SetMaxIdleConns(25)

	// 1.5 Redis Infrastructure
	redisClient := redis.NewRedisClient()

	// 2. Service Initialization
	alertService := service.NewAlertService()
	cryptoService := service.NewCryptoService() // Security Init
	fxService := service.NewFXService(database.DB)
	fxService.StartFXScheduler(context.Background()) // Start FX loop

	// Pass redisClient to WalletService
	walletService := service.NewWalletService(database.DB, fxService, alertService, redisClient)
	kycService := service.NewKYCService(database.DB, cryptoService)

	// 3. Handler Initialization
	transferHandler := &TransferHandler{Service: walletService}
	paymentHandler := NewPaymentHandler(walletService)
	kycHandler := NewKYCHandler(kycService)
	routingService := routing.NewStaticRouter(walletService)
	routingHandler := NewRoutingHandler(routingService)

	// 4. Router Setup
	r := gin.Default()
	v1 := r.Group("/api/v1")
	v1.Use(middleware.AuthMiddleware()) // Apply Auth
	v1.Use(middleware.RateLimiterMiddleware(redisClient)) // Pass Redis to RateLimiter
	{
		v1.POST("/transfer", transferHandler.HandleTransfer)
		v1.GET("/balance", transferHandler.HandleBalance)
		v1.GET("/transactions", transferHandler.HandleGetTransactions)
		v1.GET("/rates/latest", transferHandler.HandleGetLatestRate)

		// Smart Routing
		v1.GET("/quote", routingHandler.HandleGetQuote)

		// Payment Routes (Protected)
		v1.POST("/payments/create-intent", paymentHandler.HandleCreateIntent)
		
		// KYC Routes (Encrypted)
		v1.POST("/kyc", kycHandler.HandleSubmitKYC)
		v1.GET("/kyc", kycHandler.HandleGetKYC)
	}

	// Webhooks (Public)
	r.POST("/hooks/stripe", paymentHandler.HandleWebhook)

	// 5. Start Server
	log.Println("Starting server on :8080")
	if err := r.Run(":8080"); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

package main

import (
	"context"
	"log"
	"os"
	"paysif/cmd/api/middleware"
	"paysif/database"
	"paysif/internal/infrastructure/logger"
	"paysif/internal/infrastructure/redis"
	"paysif/internal/routing"
	"paysif/internal/service"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/joho/godotenv/autoload" // Optional: for local .env
)

func main() {
	// 0. Initialize Structured Logger (World-Class JSON Logging)
	logger.Init()

	// 1. Database Connection
	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()
	
	// Professional DB Tuning
	database.DB.SetMaxOpenConns(25)
	database.DB.SetMaxIdleConns(5)
	database.DB.SetConnMaxIdleTime(1 * time.Minute)

	// 1.5 Redis Infrastructure
	redisClient := redis.NewRedisClient()

	// 2. Service Initialization
	auditService := service.NewAuditService(database.DB)
	alertService := service.NewAlertService()
	cryptoService := service.NewCryptoService() // Security Init
	fxService := service.NewFXService(database.DB)
	fxService.StartFXScheduler(context.Background()) // Start FX loop

	// Pass redisClient and AuditService to WalletService
	walletService := service.NewWalletService(database.DB, fxService, alertService, redisClient, auditService)
	kycService := service.NewKYCService(database.DB, cryptoService, auditService)

	// 3. Handler Initialization
	transferHandler := &TransferHandler{Service: walletService}
	paymentHandler := NewPaymentHandler(walletService)
	payoutHandler := NewPayoutHandler(walletService)
	kycHandler := NewKYCHandler(kycService)
	routingService := routing.NewStaticRouter(walletService)
	routingHandler := NewRoutingHandler(routingService)

	// 4. Router Setup
	if mode := os.Getenv("GIN_MODE"); mode != "" {
		gin.SetMode(mode)
	}
	
	r := gin.New() // Use New() to avoid default logger
	r.Use(gin.Recovery()) // Recovery from panics
	r.Use(middleware.StructuredLogger()) // World-Class JSON Logger
	
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

		// Payout Routes (Wallet -> External)
		v1.POST("/payout/promptpay", payoutHandler.HandlePromptPayPayout)
		
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

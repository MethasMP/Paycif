package main

import (
	"context"
	"log" // Added for HandlerGetLimits return type logic if needed, but mainly standard lib
	"os"
	"paysif/cmd/api/middleware"
	"paysif/database"
	fxrpc "paysif/internal/grpc"    // Rename for clarity
	fx_pb "paysif/internal/grpc/pb" // Import pb for FXServiceClient type
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

	// 1.8 Rust Microservices Integration (Supports TCP & IPC)
	fxAddress := os.Getenv("FX_ENGINE_URL")
	if fxAddress == "" {
		// Detect if UDS is available (Secret IPC Mode)
		if _, err := os.Stat("/tmp/fx_engine.sock"); err == nil {
			fxAddress = "unix:///tmp/fx_engine.sock"
		} else {
			fxAddress = "[::1]:50052" // Default TCP
		}
	}

	fxClientConfig := &fxrpc.FXClientConfig{
		Address:            fxAddress,
		ConnectTimeout:     5 * time.Second,
		MaxRetries:         3,
		EnableHealthChecks: true,
		// mTLS config defaults to false (insecure)
	}
	
	var fxClient *fxrpc.FXClient
	var fxClientInterface fxrpc.FXClientInterface
	var sigServiceClient fx_pb.FXServiceClient

	fxClient, err := fxrpc.NewFXClientWithConfig(fxClientConfig)
	if err != nil {
		// Log but don't fatal? No, for Survivability, if Engine is critical, maybe warn.
		// But since we have DB fallback, we can proceed!
		log.Printf("⚠️ WARNING: Could not connect to Rust FX Engine: %v. Running in degraded mode (DB-only).", err)
		// fxClient remains nil
	} else {
		log.Println("✅ Connected to High-Performance Rust FX Engine")
		defer fxClient.Close()
		fxClientInterface = fxClient
		sigServiceClient = fxClient.GetClient()
	}

	// 2. Service Initialization
	auditService := service.NewAuditService(database.DB)
	alertService := service.NewAlertService()
	cryptoService := service.NewCryptoService() // Security Init
	fxService := service.NewFXService(database.DB, fxClientInterface) // Inject Rust Client (or nil)
	fxService.StartFXScheduler(context.Background()) // Start FX loop

	// Pass redisClient and AuditService to WalletService
	walletService := service.NewWalletService(database.DB, fxService, alertService, redisClient, auditService)
	kycService := service.NewKYCService(database.DB, cryptoService, auditService)
	sigService := service.NewSignatureService(sigServiceClient) // Inject Rust gRPC Client (or nil) 🛡️

	// 3. Handler Initialization
	transferHandler := &TransferHandler{
		Service:          walletService,
		SignatureService: sigService,
	}
	paymentHandler := NewPaymentHandler(walletService)
	payoutHandler := NewPayoutHandler(walletService, sigService)
	kycHandler := NewKYCHandler(kycService)
	routingService := routing.NewStaticRouter(walletService)
	routingHandler := NewRoutingHandler(routingService)

	// 4. Router Setup
	if mode := os.Getenv("GIN_MODE"); mode != "" {
		gin.SetMode(mode)
	}
	
	r := gin.New() // Use New() to avoid default logger
	r.SetTrustedProxies(nil) // Security: Disable trusting all proxies
	r.Use(gin.Recovery()) // Recovery from panics
	r.Use(middleware.StructuredLogger()) // World-Class JSON Logger
	
	v1 := r.Group("/api/v1")
	v1.Use(middleware.AuthMiddleware()) // Apply Auth
	v1.Use(middleware.RateLimiterMiddleware(redisClient)) // Pass Redis to RateLimiter
	{
		v1.POST("/transfer", transferHandler.HandleTransfer)
		v1.GET("/balance", transferHandler.HandleBalance)
		v1.GET("/limits", transferHandler.HandleGetLimits) // New Route for Rust Limits
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

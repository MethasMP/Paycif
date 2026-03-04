package main

import (
	"context"
	"log/slog" // Added for HandlerGetLimits return type logic if needed, but mainly standard lib
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
		slog.Error("Failed to connect to database", "error", err)
		os.Exit(1)
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
		slog.Warn("Could not connect to Rust FX Engine. Running in degraded mode (DB-only).", "error", err)
		// fxClient remains nil
	} else {
		slog.Info("Connected to High-Performance Rust FX Engine")
		defer fxClient.Close()
		fxClientInterface = fxClient
		sigServiceClient = fxClient.GetClient()
	}

	// 2. Service Initialization
	auditService := service.NewAuditService(database.DB)
	alertService := service.NewAlertService()
	cryptoService := service.NewCryptoService() // Security Init
	fxService := service.NewFXService(database.DB, fxClientInterface, redisClient) // Inject Rust Client and Redis
	fxService.StartFXScheduler(context.Background()) // Start FX loop

	// Pass redisClient and AuditService to WalletService
	walletService := service.NewWalletService(database.DB, fxService, alertService, redisClient, auditService)
	kycService := service.NewKYCService(database.DB, cryptoService, auditService)
	sigService := service.NewSignatureService(sigServiceClient, database.DB) // Inject Rust gRPC Client and DB 🛡️

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
	r.Use(middleware.Recovery()) // 🛡️ Secure Recovery from panics
	r.Use(middleware.StructuredLogger()) // World-Class JSON Logger
	r.Use(middleware.CORSMiddleware()) // CORS Configuration
	r.Use(middleware.SecurityHeadersMiddleware()) // Standard Security Headers
	
	v1 := r.Group("/api/v1")
	v1.Use(middleware.AuthMiddleware(walletService)) // Apply Auth with Service injection 🛡️
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
		v1.POST("/kyc/nfc", kycHandler.HandleSubmitNfcPassport) // Highly secure NFC Validation
		v1.POST("/kyc/selfie", kycHandler.HandleSubmitSelfie)  // Biometric matching
		v1.GET("/kyc", kycHandler.HandleGetKYC)
	}

	// Webhooks (Public)
	r.POST("/hooks/stripe", paymentHandler.HandleWebhook)

	// SEO (Search Engine Optimization)
	r.GET("/robots.txt", func(c *gin.Context) {
		c.String(200, "User-agent: *\nAllow: /\nSitemap: https://paycif.com/sitemap.xml")
	})

	// 5. Start Server
	slog.Info("Starting server", "port", 8080)
	if err := r.Run(":8080"); err != nil {
		slog.Error("Failed to start server", "error", err)
		os.Exit(1)
	}
}

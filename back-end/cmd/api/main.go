package main

import (
	"context"
	"log/slog" // Added for HandlerGetLimits return type logic if needed, but mainly standard lib
	"os"
	"paysif/cmd/api/middleware"
	fxrpc "paysif/internal/adapter/grpc"    // Rename for clarity
	fx_pb "paysif/internal/adapter/grpc/pb" // Import pb for FXServiceClient type
	"paysif/internal/adapter/handler"
	"paysif/internal/adapter/repository"
	"paysif/internal/infrastructure/logger"
	"paysif/internal/usecase"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/joho/godotenv/autoload" // Optional: for local .env
)

func main() {
	// 0. Initialize Structured Logger (World-Class JSON Logging)
	logger.Init()

	// 1. Database Connection
	if err := repository.Connect(); err != nil {
		slog.Error("Failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer repository.Close()

	// Professional DB Tuning
	repository.DB.SetMaxOpenConns(25)
	repository.DB.SetMaxIdleConns(5)
	repository.DB.SetConnMaxIdleTime(1 * time.Minute)

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
		slog.Error("Failed to initialize FX Client infrastructure", "error", err)
		os.Exit(1)
	}

	slog.Info("Rust FX Engine integration initialized", "address", fxAddress)
	defer fxClient.Close()
	fxClientInterface = fxClient
	sigServiceClient = fxClient.GetClient()

	// 2. Service Initialization
	auditService := usecase.NewAuditService(repository.DB)
	alertService := usecase.NewAlertService()
	fxService := usecase.NewFXService(repository.DB, fxClientInterface) // Inject Rust Client
	fxService.StartFXScheduler(context.Background())                    // Start FX loop

	// 2.5 Payment Engine Initialization (Provider Abstraction)
	sqrilBaseURL := os.Getenv("SQRIL_BASE_URL")
	if sqrilBaseURL == "" {
		sqrilBaseURL = "https://stg-api.sqril.io"
	}
	sqrilProvider := usecase.NewSqrilProvider(
		sqrilBaseURL,
		os.Getenv("SQRIL_CLIENT_ID"),
		os.Getenv("SQRIL_CLIENT_SECRET"),
	)

	paymentEngine := usecase.NewPaymentEngine("sqril") // Default to SQRIL
	paymentEngine.RegisterProvider(sqrilProvider)
	paymentEngine.RegisterProvider(&usecase.OmiseProvider{APIKey: os.Getenv("OMISE_API_KEY")})
	paymentEngine.RegisterProvider(&usecase.WiseProvider{Token: os.Getenv("WISE_API_TOKEN")})

	// Pass AuditService to WalletService
	walletService := usecase.NewWalletService(repository.DB, fxService, alertService, auditService, paymentEngine)
	kycService := usecase.NewKYCService(repository.DB, auditService)
	sigService := usecase.NewSignatureService(sigServiceClient, repository.DB) // Inject Rust gRPC Client and DB 🛡️

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

	r := gin.New()                                // Use New() to avoid default logger
	r.SetTrustedProxies(nil)                      // Security: Disable trusting all proxies
	r.Use(middleware.Recovery())                  // 🛡️ Secure Recovery from panics
	r.Use(middleware.StructuredLogger())          // World-Class JSON Logger
	r.Use(middleware.CORSMiddleware())            // CORS Configuration
	r.Use(middleware.SecurityHeadersMiddleware()) // Standard Security Headers

	publicV1 := r.Group("/api/v1")
	{
		publicV1.GET("/rates/latest", transferHandler.HandleGetLatestRate)
		publicV1.POST("/kyc/onramp-webhook", kycHandler.HandleOnRampKycWebhook)
	}

	v1 := r.Group("/api/v1")
	v1.Use(middleware.AuthMiddleware(walletService)) // Apply Auth with Service injection 🛡️
	v1.Use(middleware.RateLimiterMiddleware())       // Use local in-memory RateLimiter
	{
		v1.GET("/balance", transferHandler.HandleBalance)
		v1.GET("/limits", transferHandler.HandleGetLimits) // New Route for Rust Limits
		v1.GET("/transactions", transferHandler.HandleGetTransactions)
		v1.GET("/quote", routingHandler.HandleGetQuote) // requires user_id from auth context

		// Payment Routes (Protected)
		v1.POST("/payments/create-intent", paymentHandler.HandleCreateIntent)

		// Payout Routes (Wallet -> External)
		v1.POST("/payout/promptpay", payoutHandler.HandlePromptPayPayout)
		v1.POST("/payout/decode", payoutHandler.HandleDecodeQR)
		v1.POST("/payout/quote", payoutHandler.HandleGetQuotation)

		// KYC Routes (On-Ramp Scaffolding)
		v1.POST("/kyc/register", kycHandler.HandleRegisterOnRampCustomer)
		v1.GET("/kyc/status", kycHandler.HandleGetOnRampKycStatus)
	}

	// Webhooks (Public)
	r.POST("/hooks/alchemypay", paymentHandler.HandleWebhook)

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

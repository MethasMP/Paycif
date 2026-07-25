package main

import (
	"context"
	"log/slog" // Added for HandlerGetLimits return type logic if needed, but mainly standard lib
	"net/http"
	_ "net/http/pprof" // Register pprof endpoints
	"os"
	"paysif/cmd/api/middleware"
	fxrpc "paysif/internal/adapter/grpc" // Rename for clarity
	"paysif/internal/adapter/handler"
	"paysif/internal/adapter/repository"
	"paysif/internal/infrastructure/logger"
	"paysif/internal/usecase"
	"strings"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/joho/godotenv/autoload" // Optional: for local .env
)

func main() {
	// 0. Initialize Structured Logger (World-Class JSON Logging)
	logger.Init()

	// 0.5 Raise File Descriptor Limits for High Concurrency Performance
	var rLimit syscall.Rlimit
	if err := syscall.Getrlimit(syscall.RLIMIT_NOFILE, &rLimit); err == nil {
		rLimit.Cur = 65535
		if rLimit.Max < 65535 {
			rLimit.Max = 65535
		}
		if err := syscall.Setrlimit(syscall.RLIMIT_NOFILE, &rLimit); err != nil {
			slog.Warn("Failed to raise file descriptor limit", "error", err)
		} else {
			slog.Info("Successfully raised file descriptor limits to 65535")
		}
	}

	// 1. Database Connection
	if err := repository.Connect(); err != nil {
		slog.Error("Failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer repository.Close()

	// Professional DB Tuning (Balanced for 100 max connections)
	repository.DB.SetMaxOpenConns(30)
	repository.DB.SetMaxIdleConns(10)
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

	fxClient, err := fxrpc.NewFXClientWithConfig(fxClientConfig)
	if err != nil {
		slog.Error("Failed to initialize FX Client infrastructure", "error", err)
		os.Exit(1)
	}

	slog.Info("Rust FX Engine integration initialized", "address", fxAddress)
	defer fxClient.Close()
	fxClientInterface = fxClient

	// 2. Service Initialization
	auditService := usecase.NewAuditService(repository.DB)
	alertService := usecase.NewAlertService()
	fxService := usecase.NewFXService(repository.DB, fxClientInterface) // Inject Rust Client

	// 2.5 Payment Engine Initialization (Provider Abstraction)
	sqrilBaseURL := os.Getenv("SQRIL_BASE_URL")
	if sqrilBaseURL == "" {
		sqrilBaseURL = "https://stg-api.sqril.io"
	}
	sqrilProvider := usecase.NewSqrilProvider(
		sqrilBaseURL,
		os.Getenv("SQRIL_CLIENT_ID"),
		os.Getenv("SQRIL_CLIENT_SECRET"),
		repository.DB,
	)

	paymentEngine := usecase.NewPaymentEngine("sqril") // Default to SQRIL
	paymentEngine.RegisterProvider(sqrilProvider)
	paymentEngine.RegisterProvider(&usecase.WiseProvider{Token: os.Getenv("WISE_API_TOKEN")})

		// Pass AuditService to PaymentOrchestrationService
	orchService := usecase.NewPaymentOrchestrationService(repository.DB, fxService, alertService, auditService, paymentEngine)
	usecase.StartReconciliationWorker(context.Background(), repository.DB, orchService) // Start transaction reconciler 🔄
	achKYCClient := usecase.NewAlchemyPayKYCClient(
		os.Getenv("ALCHEMY_PAY_APP_ID"),
		os.Getenv("ALCHEMY_PAY_APP_SECRET"),
		os.Getenv("ALCHEMY_PAY_MERCHANT_NO"),
		os.Getenv("ALCHEMY_PAY_SANDBOX") != "false",
	)
	kycService := usecase.NewKYCService(repository.DB, auditService, achKYCClient)
	verifyServiceUDS := os.Getenv("VERIFY_SERVICE_UDS")
	if verifyServiceUDS == "" {
		verifyServiceUDS = "/tmp/verify_service.sock"
	}
	sigService := usecase.NewSignatureService(repository.DB, verifyServiceUDS)

	// 2.8 Alchemy Pay On-Ramp Adapter
	achAppID := os.Getenv("ALCHEMY_PAY_APP_ID")
	achAppSecret := os.Getenv("ALCHEMY_PAY_APP_SECRET")
	achSandbox := os.Getenv("ALCHEMY_PAY_SANDBOX") != "false"
	achAdapter := usecase.NewAlchemyPayAdapter(achAppID, achAppSecret, achSandbox)

	// 2.9 Geo-fencing: Thailand-only regulatory block on money-movement routes
	geoBlockSvc := usecase.NewGeoBlockService()
	vpnDetectionSvc := usecase.NewVPNDetectionService()

	// 2.95 Cloudflare bypass detection: Fly.io always exposes a public
	// *.fly.dev URL that skips Cloudflare's edge/WAF entirely, which would
	// let an attacker forge CF-Connecting-IP and defeat every geo-fencing
	// check above. Fail closed at boot if the Cloudflare IP range list can't
	// be loaded at all — starting up with TrustedPlatform=Cloudflare set but
	// no way to verify CF-Connecting-IP is unsafe.
	cfIPSvc := usecase.NewCloudflareIPRangeService()
	if err := cfIPSvc.Start(context.Background()); err != nil {
		slog.Error("Failed to load Cloudflare IP ranges at boot — refusing to start with an unverified Cloudflare-trust boundary", "error", err)
		os.Exit(1)
	}
	defer cfIPSvc.Stop()

	// Security-incident log (raw IP, service-role-only) for bypass-rejection
	// events — separate from AuditService's IP-truncated business-event log.
	securityEventSvc := usecase.NewSecurityEventService(repository.DB)

	// 3. Handler Initialization
	transferHandler := &TransferHandler{
		Service:          orchService,
		SignatureService: sigService,
	}
	paymentHandler := NewPaymentHandler(orchService, achAdapter, fxService, geoBlockSvc)
	payoutHandler := NewPayoutHandler(orchService, sigService)
	kycHandler := NewKYCHandler(kycService)
	routingService := routing.NewStaticRouter(orchService)
	routingHandler := NewRoutingHandler(routingService)

	// 4. Router Setup
	if mode := os.Getenv("GIN_MODE"); mode != "" {
		gin.SetMode(mode)
	}

	r := gin.New() // Use New() to avoid default logger

	// Trust CF-Connecting-IP as the real client IP everywhere c.ClientIP()
	// is called. Safe only because CloudflareBypassMiddleware (registered
	// first, below) rejects any request whose Fly-Client-IP isn't a real
	// Cloudflare edge IP — i.e. anything that hit *.fly.dev directly. Not
	// env-gated: correctness now depends on that middleware always being
	// registered (enforced by ValidateCloudflareTrustConfig at boot), not on
	// an admin setting an env var correctly.
	r.TrustedPlatform = gin.PlatformCloudflare

	// This CIDR-based trusted-proxy list is now a fallback, not the primary
	// mechanism: TrustedPlatform (above) takes CF-Connecting-IP unconditionally
	// wherever it's consulted, and gin only falls through to this list's
	// X-Forwarded-For parsing for headers TrustedPlatform doesn't cover.
	// CloudflareBypassMiddleware below is registered globally (r.Use, before
	// any group or direct route is declared), so it already covers every
	// route on r — including /hooks/* and /robots.txt registered directly on
	// r further down — not just v1/moneyMovement. This CIDR fallback exists
	// purely for any future route added to r that, for its own reasons,
	// shouldn't require passing through Cloudflare. Do not set it to "*" or a
	// broad range, since a trusted proxy is one whose X-Forwarded-For value
	// we blindly believe.
	if raw := os.Getenv("TRUSTED_PROXIES"); raw != "" {
		proxies := []string{}
		for _, p := range strings.Split(raw, ",") {
			if p = strings.TrimSpace(p); p != "" {
				proxies = append(proxies, p)
			}
		}
		if err := r.SetTrustedProxies(proxies); err != nil {
			slog.Error("Invalid TRUSTED_PROXIES value", "value", raw, "error", err)
			os.Exit(1)
		}
	} else {
		r.SetTrustedProxies(nil) // Security: trust nobody's X-Forwarded-For until configured
	}

	r.Use(middleware.CloudflareBypassMiddleware(cfIPSvc, securityEventSvc)) // MUST run before anything using c.ClientIP()
	r.Use(middleware.Recovery())                                            // 🛡️ Secure Recovery from panics
	r.Use(middleware.StructuredLogger())                                    // World-Class JSON Logger
	r.Use(middleware.CORSMiddleware())                                      // CORS Configuration
	r.Use(middleware.SecurityHeadersMiddleware())                           // Standard Security Headers

	publicV1 := r.Group("/api/v1")
	{
		publicV1.POST("/kyc/onramp-webhook", kycHandler.HandleOnRampKycWebhook)
	}

	publicGeofencedV1 := r.Group("/api/v1")
	publicGeofencedV1.Use(middleware.GeoBlockMiddleware(geoBlockSvc, auditService))
	publicGeofencedV1.Use(middleware.VPNDetectionMiddleware(vpnDetectionSvc, auditService))
	{
		publicGeofencedV1.GET("/rates/latest", transferHandler.HandleGetLatestRate)
	}

	v1 := r.Group("/api/v1")
	v1.Use(middleware.AuthMiddleware(orchService)) // Apply Auth with Service injection 🛡️
	v1.Use(middleware.RateLimiterMiddleware())       // Use local in-memory RateLimiter
	v1.Use(middleware.GeoBlockMiddleware(geoBlockSvc, auditService))
	v1.Use(middleware.VPNDetectionMiddleware(vpnDetectionSvc, auditService))
	{
		v1.GET("/balance", transferHandler.HandleBalance)
		v1.GET("/limits", transferHandler.HandleGetLimits) // New Route for Rust Limits
		v1.GET("/transactions", transferHandler.HandleGetTransactions)
		v1.GET("/quote", routingHandler.HandleGetQuote) // requires user_id from auth context

		// On-Ramp Routes (Protected)
		v1.GET("/onramp/check-region", paymentHandler.HandleCheckRegion)
		v1.POST("/onramp/quote", paymentHandler.HandleGetQuote)
		v1.GET("/onramp/token", paymentHandler.HandleGetAchToken)
		v1.GET("/onramp/fiat-methods", paymentHandler.HandleFiatList)
		v1.GET("/onramp/manage-url", paymentHandler.HandleGetManageUrl)
		v1.GET("/payments/intent/:id/status", paymentHandler.HandleGetIntentStatus)

		// Payout Routes (Wallet -> External)
		v1.POST("/payout/decode", payoutHandler.HandleDecodeQR)
		v1.POST("/payout/quote", payoutHandler.HandleGetQuotation)

		// KYC Routes (On-Ramp Scaffolding)
		v1.POST("/kyc/register", kycHandler.HandleRegisterOnRampCustomer)
		v1.GET("/kyc/status", kycHandler.HandleGetOnRampKycStatus)

		// Money-movement routes
		v1.POST("/onramp/create", paymentHandler.HandleCreateOnRampOrder)
		v1.POST("/payments/create-intent", paymentHandler.HandleCreateIntent)
		v1.POST("/payout/promptpay", payoutHandler.HandlePromptPayPayout)
	}

	// Webhooks (Public)
	r.POST("/hooks/alchemypay", paymentHandler.HandleWebhook)
	r.POST("/hooks/sqril", payoutHandler.HandleSqrilWebhook)

	// SEO (Search Engine Optimization)
	r.GET("/robots.txt", func(c *gin.Context) {
		c.String(200, "User-agent: *\nAllow: /\nSitemap: https://paycif.com/sitemap.xml")
	})

	// 4.5 Startup guard: refuse to run if TrustedPlatform trusts Cloudflare
	// but the bypass middleware that makes that trust safe isn't registered.
	if err := middleware.ValidateCloudflareTrustConfig(r); err != nil {
		slog.Error("startup guard failed", "error", err)
		os.Exit(1)
	}

	// 5. Start Pprof Server (Internal Only for Security)
	go func() {
		slog.Info("Starting internal pprof server", "port", 6060)
		if err := http.ListenAndServe("127.0.0.1:6060", nil); err != nil {
			slog.Error("pprof server failed", "error", err)
		}
	}()

	// 6. Start Main API Server
	slog.Info("Starting server", "port", 8080)
	if err := r.Run(":8080"); err != nil {
		slog.Error("Failed to start server", "error", err)
		os.Exit(1)
	}
}

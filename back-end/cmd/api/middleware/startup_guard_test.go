package middleware

import (
	"testing"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
)

func TestValidateCloudflareTrustConfig_FiresWhenBypassMissing(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.TrustedPlatform = gin.PlatformCloudflare
	// Deliberately no r.Use(CloudflareBypassMiddleware(...)).

	if err := ValidateCloudflareTrustConfig(r); err == nil {
		t.Fatal("expected an error when TrustedPlatform is Cloudflare but the bypass middleware isn't registered")
	}
}

func TestValidateCloudflareTrustConfig_PassesWhenBypassRegistered(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.TrustedPlatform = gin.PlatformCloudflare
	r.Use(CloudflareBypassMiddleware(usecase.NewCloudflareIPRangeService(), nil))

	if err := ValidateCloudflareTrustConfig(r); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestValidateCloudflareTrustConfig_NoOpWhenNotTrustingCloudflare(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New() // TrustedPlatform left empty

	if err := ValidateCloudflareTrustConfig(r); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

package middleware

import (
	"fmt"
	"reflect"
	"runtime"
	"strings"

	"github.com/gin-gonic/gin"
)

// ValidateCloudflareTrustConfig fails if r.TrustedPlatform trusts
// CF-Connecting-IP (gin.PlatformCloudflare) but CloudflareBypassMiddleware
// isn't actually registered in r's handler chain — the one configuration
// that would make Gin blindly trust an attacker-forged CF-Connecting-IP
// header on any request that reaches this process directly via the public
// *.fly.dev URL, bypassing Cloudflare entirely.
//
// It introspects r.Handlers directly (the exported RouterGroup field
// populated by r.Use) rather than trusting a hand-maintained bool, so a
// future refactor that drops the r.Use(CloudflareBypassMiddleware(...))
// call still gets caught even without anyone touching this guard.
func ValidateCloudflareTrustConfig(r *gin.Engine) error {
	if r.TrustedPlatform != gin.PlatformCloudflare {
		return nil
	}

	for _, h := range r.Handlers {
		name := runtime.FuncForPC(reflect.ValueOf(h).Pointer()).Name()
		if strings.Contains(name, "CloudflareBypassMiddleware") {
			return nil
		}
	}

	return fmt.Errorf("TrustedPlatform is gin.PlatformCloudflare but CloudflareBypassMiddleware is not registered — CF-Connecting-IP would be trusted unconditionally, including from requests that bypass Cloudflare via the public *.fly.dev URL")
}

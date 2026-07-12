package middleware

import (
	"log"
	"net/http"
	"os"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
)

// CloudflareBypassMiddleware guards the Cloudflare-trust boundary: Fly.io
// always exposes a public *.fly.dev URL that bypasses Cloudflare's edge/WAF
// entirely, and a request that hits the app that way can forge any
// CF-Connecting-IP header it likes. Since the engine trusts CF-Connecting-IP
// (via gin.PlatformCloudflare) for every downstream c.ClientIP() consumer —
// geo-fencing, VPN detection, rate limiting, audit logging — this middleware
// MUST run before all of them.
//
// It reads Fly-Client-IP, which Fly's own edge proxy sets from the real TCP
// peer and which an external client cannot forge, and checks it against
// Cloudflare's published IP ranges. A request whose Fly-Client-IP isn't a
// real Cloudflare edge IP did not come through Cloudflare and is rejected —
// with the same opaque error body used by GeoBlockMiddleware/
// VPNDetectionMiddleware, so an attacker probing which layer blocked them
// can't tell this apart from a country or VPN block.
// securityEvents may be nil (e.g. in unit tests, or if DB wiring changes) —
// SecurityEventService.LogCloudflareBypassRejection no-ops on a nil service,
// so this middleware degrades to log.Printf-only recording rather than
// panicking.
func CloudflareBypassMiddleware(svc *usecase.CloudflareIPRangeService, securityEvents *usecase.SecurityEventService) gin.HandlerFunc {
	return func(c *gin.Context) {
		flyClientIP := c.GetHeader("Fly-Client-IP")

		if flyClientIP == "" {
			// No Fly edge in front of this request at all — local dev,
			// docker-compose, or a staging environment not yet behind
			// Fly/Cloudflare. DISABLE_CLOUDFLARE_BYPASS_CHECK is an explicit,
			// separately-named escape hatch (not tied to GIN_MODE) so it
			// can't silently apply to a real release deploy mid-migration.
			if usecase.IsLocalIP(c.ClientIP()) || os.Getenv("DISABLE_CLOUDFLARE_BYPASS_CHECK") == "true" {
				c.Next()
				return
			}

			log.Printf("cloudflare_bypass: rejected request with no Fly-Client-IP header, path=%s", c.Request.URL.Path)
			securityEvents.LogCloudflareBypassRejection("", c.Request.URL.Path, c.Request.Method, c.Request.UserAgent(), c.GetHeader("X-Request-ID"), false)
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "service_unavailable_in_region"})
			return
		}

		if !svc.Contains(flyClientIP) {
			log.Printf("cloudflare_bypass: rejected fly-client-ip=%s not in Cloudflare's published ranges, path=%s", usecase.TruncateIP(flyClientIP), c.Request.URL.Path)
			securityEvents.LogCloudflareBypassRejection(flyClientIP, c.Request.URL.Path, c.Request.Method, c.Request.UserAgent(), c.GetHeader("X-Request-ID"), false)
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "service_unavailable_in_region"})
			return
		}

		c.Next()
	}
}

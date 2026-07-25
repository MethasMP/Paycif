package middleware

import (
	"log"
	"net/http"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// VPNDetectionMiddleware is the second, independent geo-fencing check: it
// catches a user physically outside Thailand who routes through a
// Thailand-exit VPN to defeat GeoBlockMiddleware's country lookup. Both
// middlewares must pass for a money-movement request to proceed.
//
// Deliberately returns the identical error body as GeoBlockMiddleware
// ("service_unavailable_in_region") rather than a distinct code — an
// attacker probing which layer blocked them shouldn't be able to tell VPN
// detection from a plain country block. The audit log (action "vpn_block")
// keeps the real distinction for internal review.
//
// If the IPQS lookup fails, the service fails open (see
// vpn_detection_service.go) and this middleware simply lets the request
// through — same philosophy as GeoBlockMiddleware.
func VPNDetectionMiddleware(svc *usecase.VPNDetectionService, audit *usecase.AuditService) gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if usecase.IsLocalIP(ip) {
			c.Next()
			return
		}

		userAgent := c.Request.UserAgent()
		userLang := c.Request.Header.Get("Accept-Language")
		suspicious, err := svc.IsSuspiciousWithHeaders(c.Request.Context(), ip, userAgent, userLang)

		if err != nil {
			// Adaptive Failover Strategy (Enterprise Grade):
			// When external IP lookup services are experiencing an outage/quota limit,
			// rather than causing a 100% platform outage for legitimate Thailand users,
			// mark the context with `require_step_up` = true to enforce mandatory Liveness/OTP
			// verification on money-movement endpoints downstream.
			log.Printf("vpn_block: lookup degraded for ip=%s: %v — setting require_step_up=true", usecase.TruncateIP(ip), err)
			c.Set("require_step_up", true)
			c.Next()
			return
		}

		if !suspicious {
			c.Next()
			return
		}

		if userIDStr := c.GetString("user_id"); userIDStr != "" {
			if userID, parseErr := uuid.Parse(userIDStr); parseErr == nil {
				audit.Log(c.Request.Context(), userID, "vpn_block", "payment", "", map[string]interface{}{
					"ip_truncated": usecase.TruncateIP(ip),
					"path":         c.Request.URL.Path,
				})
			}
		} else {
			log.Printf("vpn_block: blocked suspicious (vpn/proxy/tor/high-fraud-score) request ip=%s path=%s (no authenticated user_id in context)", usecase.TruncateIP(ip), c.Request.URL.Path)
		}

		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "service_unavailable_in_region"})
	}
}

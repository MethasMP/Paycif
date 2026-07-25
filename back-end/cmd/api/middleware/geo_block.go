package middleware

import (
	"log"
	"net/http"

	"paysif/internal/usecase"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// GeoBlockMiddleware enforces the Thailand-only regulatory geo-fence on
// money-movement routes. It resolves the client IP to a country via
// GeoBlockService and rejects requests from blocked countries (US/UK/EU).
// If the lookup itself fails, the service fails open (see geo_block_service.go)
// and this middleware simply lets the request through.
func GeoBlockMiddleware(svc *usecase.GeoBlockService, audit *usecase.AuditService) gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if usecase.IsLocalIP(ip) {
			c.Next()
			return
		}

		country, err := svc.ResolveCountry(c.Request.Context(), ip)
		if err != nil {
			// Fail closed: lookup unavailable, reject request for safety.
			log.Printf("geo_block: lookup failed for ip=%s (fail-closed): %v", usecase.TruncateIP(ip), err)
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "service_unavailable_in_region"})
			return
		}

		if svc.IsAllowed(country) {
			c.Next()
			return
		}

		if userIDStr := c.GetString("user_id"); userIDStr != "" {
			if userID, parseErr := uuid.Parse(userIDStr); parseErr == nil {
				audit.Log(c.Request.Context(), userID, "geo_block", "payment", "", map[string]interface{}{
					"ip_truncated": usecase.TruncateIP(ip),
					"country":      country,
					"path":         c.Request.URL.Path,
				})
			}
		} else {
			log.Printf("geo_block: blocked request from country=%s ip=%s path=%s (no authenticated user_id in context)", country, usecase.TruncateIP(ip), c.Request.URL.Path)
		}

		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "service_unavailable_in_region"})
	}
}

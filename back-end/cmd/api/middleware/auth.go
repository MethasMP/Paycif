package middleware

import (
	"context"
	"log"
	"net/http"
	"os"
	"paysif/internal/service"
	"strings"
	"time"

	"github.com/MicahParks/keyfunc/v2"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var jwks *keyfunc.JWKS

// AuthMiddleware validates Supabase JWT using JWKS and sets userID in context.
func AuthMiddleware(walletSvc *service.WalletService) gin.HandlerFunc {
	jwksURL := os.Getenv("JWKS_URL")
	if jwksURL == "" {
		jwksURL = "https://iybequvtfiqoexnhfwvb.supabase.co/auth/v1/.well-known/jwks.json"
	}
	expectedAudience := os.Getenv("JWT_AUDIENCE")

	// Initialize JWKS once
	var err error
	options := keyfunc.Options{
		RefreshInterval: time.Hour,
		RefreshTimeout:  10 * time.Second,
		RefreshErrorHandler: func(err error) {
			log.Printf("⚠️ JWKS Refresh Error: %v\n", err)
		},
	}
	jwks, err = keyfunc.Get(jwksURL, options)
	if err != nil {
		log.Fatalf("❌ Failed to initialize JWKS: %v\n", err)
	}
	log.Println("✅ JWKS Initialized")

	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Bearer token required"})
			return
		}

		// Use JWKS Keyfunc to validate token signature
		token, err := jwt.Parse(tokenString, jwks.Keyfunc)

		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			return
		}

		// Security: Validate Audience if configured
		if expectedAudience != "" {
			aud, _ := claims.GetAudience()
			found := false
			for _, a := range aud {
				if a == expectedAudience {
					found = true
					break
				}
			}
			if !found {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid audience"})
				return
			}
		}

		sub, ok := claims["sub"].(string)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Missing subject in token"})
			return
		}

		uid, err := uuid.Parse(sub)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid user ID format"})
			return
		}

		c.Set("user_id", sub)

		// SAFETY NET: Ensure user has a wallet asynchronously via Service layer 🛡️
		go func(id uuid.UUID) {
			if err := walletSvc.EnsureUserAccount(context.Background(), id); err != nil {
				log.Printf("⚠️ Auto-Heal Error for %s: %v\n", id, err)
			}
		}(uid)

		c.Next()
	}
}

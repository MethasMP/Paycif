package middleware

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"
	"zappay/database"

	"github.com/MicahParks/keyfunc/v2"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

var jwks *keyfunc.JWKS

const jwksURL = "https://iybequvtfiqoexnhfwvb.supabase.co/auth/v1/.well-known/jwks.json"

// AuthMiddleware validates Supabase JWT using JWKS and sets userID in context.
func AuthMiddleware() gin.HandlerFunc {
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

		// Use JWKS Keyfunc to validate token signature (supports ES256, RS256, etc.)
		token, err := jwt.Parse(tokenString, jwks.Keyfunc)

		if err != nil || !token.Valid {
			fmt.Printf("⚠️ JWT Error: %v\n", err)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			if sub, ok := claims["sub"].(string); ok {
				c.Set("user_id", sub)

				// SAFETY NET: Ensure user has a wallet asynchronously
				// This prevents crashes if the Supabase Trigger failed or wasn't set up.
				go func(uid string) {
					if database.DB == nil {
						return
					}
					// 1. Ensure Profile Exists
					// We use a dummy username if creating for the first time
					_, err := database.DB.Exec(`
						INSERT INTO profiles (id, username, full_name) 
						VALUES ($1, $2, $3) 
						ON CONFLICT (id) DO NOTHING`,
						uid, "user_"+uid[:8], "ZapPay User",
					)
					if err != nil {
						log.Printf("⚠️ Auto-Heal Profile Error: %v\n", err)
						return
					}

					// 2. Ensure Wallet Exists
					// Check if wallet exists for this user
					var exists bool
					err = database.DB.QueryRow("SELECT EXISTS(SELECT 1 FROM wallets WHERE profile_id = $1)", uid).Scan(&exists)
					if err != nil {
						log.Printf("⚠️ Check Wallet Error: %v\n", err)
						return
					}

					if !exists {
						log.Printf("🔧 Auto-Healing: Creating missing wallet for %s\n", uid)
						_, err := database.DB.Exec(`
							INSERT INTO wallets (profile_id, currency, balance) 
							VALUES ($1, 'THB', 0)`,
							uid,
						)
						if err != nil {
							log.Printf("❌ Failed to create wallet: %v\n", err)
						} else {
							log.Printf("✅ Wallet created successfully for %s\n", uid)
						}
					}
				}(sub)

				c.Next()
				return
			}
		}

		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
	}
}

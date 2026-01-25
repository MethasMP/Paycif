package middleware

import (
	"fmt"
	"log"
	"net/http"
	"paysif/database"
	"strings"
	"time"

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
					
					// Start transaction for atomic auto-healing
					tx, err := database.DB.Begin()
					if err != nil {
						log.Printf("⚠️ Auth Transaction Error: %v\n", err)
						return
					}
					defer tx.Rollback()

					// 1. Ensure Profile Exists - STATELESS (Simple Protocol)
					// Safe Interploation: uid is from trusted JWT sub claims (UUID format implied), others are hardcoded/derived.
					// We escape strings just in case.
					safeUID := strings.ReplaceAll(uid, "'", "''")
					safeUsername := strings.ReplaceAll("user_"+uid[:8], "'", "''")
					
					profileSQL := fmt.Sprintf("INSERT INTO profiles (id, username, full_name) VALUES ('%s', '%s', 'Paysif User') ON CONFLICT (id) DO NOTHING", safeUID, safeUsername)
					_, err = tx.Exec(profileSQL)
					if err != nil {
						log.Printf("⚠️ Auto-Heal Profile Error: %v\n", err)
						return
					}

					// 2. Ensure Wallet Exists - STATELESS
					var exists bool
					checkWalletSQL := fmt.Sprintf("SELECT EXISTS(SELECT 1 FROM wallets WHERE profile_id = '%s')", safeUID)
					err = tx.QueryRow(checkWalletSQL).Scan(&exists)
					if err != nil {
						log.Printf("⚠️ Check Wallet Error: %v\n", err)
						return
					}

					if !exists {
						log.Printf("🔧 Auto-Healing: Creating missing wallet for %s\n", uid)
						createWalletSQL := fmt.Sprintf("INSERT INTO wallets (profile_id, currency, balance) VALUES ('%s', 'THB', 0)", safeUID)
						_, err := tx.Exec(createWalletSQL)
						if err != nil {
							log.Printf("❌ Failed to create wallet: %v\n", err)
						} else {
							log.Printf("✅ Wallet created successfully for %s\n", uid)
						}
					}
					
					_ = tx.Commit()
				}(sub)

				c.Next()
				return
			}
		}

		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
	}
}

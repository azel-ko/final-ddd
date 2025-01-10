package middleware

import (
	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
	"net/http"
	"sync"
	"time"
)

// RateLimitMiddleware creates a Gin middleware for rate limiting based on IP address.
func RateLimitMiddleware() gin.HandlerFunc {
	maxReqs := 3
	duration := 10 * time.Second

	// Cleanup configuration: check every minute, remove inactive IPs after 5 minutes.
	cleanupInterval := 1 * time.Minute
	inactivityTimeout := 5 * time.Minute
	// Use sync.Map for concurrent-safe operations without explicit locks.
	var limiters sync.Map // map[string]*rate.Limiter
	limiterLastAccess := make(map[string]time.Time)
	var mu sync.Mutex

	// Start a background goroutine to clean up old entries.
	go func() {
		ticker := time.NewTicker(cleanupInterval)
		defer ticker.Stop()
		for range ticker.C {
			now := time.Now()
			mu.Lock()
			for ip, lastAccess := range limiterLastAccess {
				if now.Sub(lastAccess) > inactivityTimeout {
					delete(limiterLastAccess, ip)
					limiters.Delete(ip)
				}
			}
			mu.Unlock()
		}
	}()

	return func(c *gin.Context) {
		ip := c.ClientIP()

		// Update the last access time for this IP.
		mu.Lock()
		limiterLastAccess[ip] = time.Now()
		mu.Unlock()

		// Retrieve or create the limiter for this IP.
		if limiter, ok := limiters.Load(ip); ok {
			if !limiter.(*rate.Limiter).Allow() {
				c.JSON(http.StatusTooManyRequests, gin.H{
					"error": "too many requests from this IP",
				})
				c.Abort()
				return
			}
		} else {
			perSecondLimit := rate.Limit(float64(maxReqs) / duration.Seconds())
			newLimiter := rate.NewLimiter(perSecondLimit, maxReqs)
			if existing, loaded := limiters.LoadOrStore(ip, newLimiter); loaded {
				// If another goroutine has already created the limiter, use it instead.
				if !existing.(*rate.Limiter).Allow() {
					c.JSON(http.StatusTooManyRequests, gin.H{
						"error": "too many requests from this IP",
					})
					c.Abort()
					return
				}
			}
		}

		c.Next()
	}
}

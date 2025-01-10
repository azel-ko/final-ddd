package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/unrolled/secure"
)

func SourceMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		secureMiddleware := secure.New(secure.Options{
			SSLRedirect:             true,
			STSSeconds:              315360000,
			STSIncludeSubdomains:    true,
			STSPreload:              true,
			FrameDeny:               true,
			CustomFrameOptionsValue: "SAMEORIGIN",
			ContentTypeNosniff:      true,
			BrowserXssFilter:        true,
			ContentSecurityPolicy:   "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';",
		})
		secureMiddleware.Process(c.Writer, c.Request)
		c.Next()
	}
}

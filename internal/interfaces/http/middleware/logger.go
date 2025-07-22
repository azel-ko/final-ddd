package middleware

import (
	"github.com/azel-ko/final-ddd/internal/pkg/logger"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"time"
)

func LoggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery
		//
		//// 请求前的日志
		//logger.Info("Incoming request",
		//	zap.String("path", path),
		//	zap.String("query", query),
		//	zap.String("ip", c.ClientIP()),
		//	zap.String("method", c.Request.Method),
		//)

		c.Next()

		// 请求后的日志
		latency := time.Since(start)
		status := c.Writer.Status()

		logFunc := logger.Info
		if status >= 400 {
			logFunc = logger.Error
		}

		if status != 404 {
			logFunc("Request completed",
				zap.Int("status", status),
				zap.Duration("latency", latency),
				zap.Int("size", c.Writer.Size()),
				zap.String("path", path),
				zap.String("query", query),
				zap.String("ip", c.ClientIP()),
				zap.String("method", c.Request.Method),
				zap.String("error", c.Errors.ByType(gin.ErrorTypePrivate).String()),
			)
		}
	}
}

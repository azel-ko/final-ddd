package middleware

import (
	"github.com/azel-ko/final-ddd/pkg/metrics"
	"github.com/gin-gonic/gin"
	"time"
)

func PrometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.FullPath()
		if path == "" {
			path = "unknown"
		}

		// 增加正在处理的请求计数
		metrics.RequestInFlight.Inc()
		defer metrics.RequestInFlight.Dec()

		// 处理请求
		c.Next()

		// 记录请求持续时间
		duration := time.Since(start).Seconds()
		metrics.RequestDuration.WithLabelValues(
			c.Request.Method,
			path,
		).Observe(duration)

		// 记录响应大小
		metrics.ResponseSize.WithLabelValues(
			c.Request.Method,
			path,
		).Observe(float64(c.Writer.Size()))

		// 记录请求总数和状态码
		metrics.RequestTotal.WithLabelValues(
			c.Request.Method,
			path,
			string(c.Writer.Status()),
		).Inc()
	}
}

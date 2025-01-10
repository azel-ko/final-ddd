package middleware

import (
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func CORSMiddleware() gin.HandlerFunc {
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true // 允许的来源列表
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Length", "Content-Type", "Authorization"}

	// 使用 cors.New 创建一个中间件实例
	corsMiddleware := cors.New(config)

	return func(c *gin.Context) {
		// 调用 CORS 中间件处理请求
		corsMiddleware(c)
		// 继续处理链中的其他中间件或路由处理函数
		c.Next()
	}
}

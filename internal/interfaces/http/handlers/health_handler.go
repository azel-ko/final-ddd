package handlers

import (
	"github.com/azel-ko/final-ddd/internal/pkg/version"
	"github.com/gin-gonic/gin"
	"net/http"
)

// HealthHandler 处理健康检查相关的请求
type HealthHandler struct{}

// NewHealthHandler 创建一个新的健康检查处理器
func NewHealthHandler() *HealthHandler {
	return &HealthHandler{}
}

// Check 返回应用程序的健康状态
func (h *HealthHandler) Check(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "ok",
		"info": version.Get(),
	})
} 
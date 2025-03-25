package handlers

import (
	"net/http"

	"github.com/azel-ko/final-ddd/internal/application/dto"
	"github.com/azel-ko/final-ddd/internal/application/services"
	"github.com/azel-ko/final-ddd/pkg/logger"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

type AuthHandler struct {
	authService *services.AuthService
}

func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req dto.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Error("Invalid login request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	response, err := h.authService.Login(c.Request.Context(), &req)
	if err != nil {
		logger.Error("Login failed",
			zap.String("email", req.Email),
			zap.Error(err),
		)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	logger.Info("User logged in successfully",
		zap.String("email", req.Email),
		zap.Uint("user_id", response.User.ID),
	)
	c.JSON(http.StatusOK, response)
}

// Register godoc
func (h *AuthHandler) Register(c *gin.Context) {
	var req dto.UserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		logger.Error("Invalid registration request", zap.Error(err))
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, err := h.authService.Register(&req)
	if err != nil {
		logger.Error("Registration failed",
			zap.String("email", req.Email),
			zap.Error(err),
		)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	logger.Info("User registered successfully",
		zap.String("email", req.Email),
		zap.Uint("user_id", user.ID),
	)
	c.JSON(http.StatusCreated, user)
}

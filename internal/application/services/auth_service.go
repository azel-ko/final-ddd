package services

import (
	"context"
	"github.com/azel-ko/final-ddd/internal/application/dto"
	"github.com/azel-ko/final-ddd/internal/application/errors"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
	"github.com/azel-ko/final-ddd/internal/infrastructure/cache"
	"github.com/azel-ko/final-ddd/pkg/auth"
	"github.com/azel-ko/final-ddd/internal/pkg/logger"
	"go.uber.org/zap"
	"time"
)

type AuthService struct {
	repo       repository.Repository
	jwtManager *auth.JWTManager
	cache      *cache.RedisCache
}

func NewAuthService(repo repository.Repository, jwtManager *auth.JWTManager, cache *cache.RedisCache) *AuthService {
	return &AuthService{
		repo:       repo,
		jwtManager: jwtManager,
		cache:      cache,
	}
}

func (s *AuthService) Login(ctx context.Context, req *dto.LoginRequest) (*dto.LoginResponse, error) {
	// 检查缓存
	var response *dto.LoginResponse
	cacheKey := "login:" + req.Email
	if err := s.cache.Get(ctx, cacheKey, &response); err == nil {
		return response, nil
	}

	user, err := s.repo.GetUserByEmail(req.Email)
	if err != nil {
		logger.Error("login failed: user not found", zap.String("email", req.Email))
		return nil, err
	}

	if err := auth.CheckPassword(req.Password, user.Password); err != nil {
		logger.Error("login failed: invalid password", zap.String("email", req.Email))
		return nil, err
	}

	token, err := s.jwtManager.GenerateToken(user.ID, user.Email, user.Role)
	if err != nil {
		logger.Error("failed to generate token", zap.Error(err))
		return nil, err
	}

	response = dto.ToLoginResponse(token, user)

	// 缓存登录响应
	if err := s.cache.Set(ctx, cacheKey, response, 15*time.Minute); err != nil {
		logger.Error("failed to cache login response", zap.Error(err))
	}

	logger.Info("user logged in successfully", zap.String("email", req.Email))
	return response, nil
}

// Register 用户注册
func (s *AuthService) Register(req *dto.UserRequest) (*dto.UserResponse, error) {
	if _, err := s.repo.GetUserByEmail(req.Email); err == nil {
		return nil, errors.ErrEmailAlreadyExists
	}

	user, err := dto.ToUserEntity(req)
	if err != nil {
		return nil, err
	}
	if err := s.repo.CreateUser(user); err != nil {
		return nil, err
	}

	return dto.ToUserResponse(user), nil
}

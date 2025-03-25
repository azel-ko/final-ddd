package dto

import (
	"github.com/azel-ko/final-ddd/internal/domain/entities"
	"github.com/azel-ko/final-ddd/pkg/auth"
)

type UserRequest struct {
	Name     string `json:"username" binding:"required"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type UserResponse struct {
	ID    uint   `json:"id"`
	Name  string `json:"username"`
	Email string `json:"email"`
}

func ToUserEntity(req *UserRequest) (*entities.User, error) {
	password, err := auth.HashPassword(req.Password)
	if err != nil {
		return nil, err
	}
	return &entities.User{
		Name:     req.Name,
		Email:    req.Email,
		Password: password, // 实际项目中应该加密
	}, nil
}

func ToUserResponse(user *entities.User) *UserResponse {
	return &UserResponse{
		ID:    user.ID,
		Name:  user.Name,
		Email: user.Email,
	}
}

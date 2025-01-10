package dto

import "github.com/azel-ko/final-ddd/internal/domain/entities"

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginResponse struct {
	Token string `json:"token"`
	User  UserResponse
}

func ToLoginResponse(token string, user *entities.User) *LoginResponse {
	return &LoginResponse{
		Token: token,
		User: UserResponse{
			ID:    user.ID,
			Email: user.Email,
			Name:  user.Name,
		},
	}
}

package services

import (
	"github.com/azel-ko/final-ddd/internal/application/dto"
	"github.com/azel-ko/final-ddd/internal/application/errors"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
)

type UserService struct {
	repo repository.Repository
}

func NewUserService(repo repository.Repository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) CreateUser(req *dto.UserRequest) (*dto.UserResponse, error) {
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

func (s *UserService) GetUser(id int) (*dto.UserResponse, error) {
	user, err := s.repo.GetUser(id)
	if err != nil {
		return nil, errors.ErrNotFound
	}
	return dto.ToUserResponse(user), nil
}

func (s *UserService) UpdateUser(id int, req *dto.UserRequest) (*dto.UserResponse, error) {
	user, err := s.repo.GetUser(id)
	if err != nil {
		return nil, errors.ErrNotFound
	}

	user.Name = req.Name
	user.Email = req.Email
	if req.Password != "" {
		user.Password = req.Password // 实际项目中应该加密
	}

	if err := s.repo.UpdateUser(user); err != nil {
		return nil, err
	}

	return dto.ToUserResponse(user), nil
}

func (s *UserService) DeleteUser(id int) error {
	return s.repo.DeleteUser(id)
}

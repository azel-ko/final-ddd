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

func (s *UserService) GetSelf(userID uint) (*dto.UserProfileResponse, error) {
	user, err := s.repo.GetUser(int(userID))
	if err != nil {
		return nil, errors.ErrNotFound
	}
	return dto.ToUserProfileResponse(user), nil
}

func (s *UserService) UpdateSelf(userID uint, req *dto.UpdateUserProfileRequest) (*dto.UserProfileResponse, error) {
	user, err := s.repo.GetUser(int(userID))
	if err != nil {
		return nil, errors.ErrNotFound
	}

	if req.Name != nil {
		user.Name = *req.Name
	}

	if req.Email != nil {
		if *req.Email != user.Email {
			// Check if the new email already exists for another user
			existingUser, err := s.repo.GetUserByEmail(*req.Email)
			if err == nil && existingUser.ID != userID { // Email exists and belongs to another user
				return nil, errors.ErrEmailAlreadyExists
			}
			// If err is not nil and it's not a "not found" error, then it's some other DB error.
			// However, GetUserByEmail typically returns a specific error for not found, which we'd ignore here.
			// For simplicity, we assume any error other than "found" means the email is available or it's a real DB issue.
			// A more robust check might be needed depending on exact error types from repo.GetUserByEmail.

			user.Email = *req.Email
		}
	}

	if err := s.repo.UpdateUserProfile(user); err != nil {
		return nil, err // Could be a generic error like errors.ErrDatabase
	}

	return dto.ToUserProfileResponse(user), nil
}

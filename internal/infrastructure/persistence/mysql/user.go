package mysql

import "github.com/azel-ko/final-ddd/internal/domain/entities"

func (r *mysqlRepository) CreateUser(user *entities.User) error {
	return r.db.Create(user).Error
}

func (r *mysqlRepository) GetUser(id int) (*entities.User, error) {
	var user entities.User
	if err := r.db.First(&user, id).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *mysqlRepository) UpdateUserProfile(user *entities.User) error {
	// Updates only Name and Email fields
	return r.db.Model(user).Select("Name", "Email").Updates(user).Error
}

func (r *mysqlRepository) UpdateUser(user *entities.User) error {
	return r.db.Save(user).Error
}

func (r *mysqlRepository) DeleteUser(id int) error {
	return r.db.Delete(&entities.User{}, id).Error
}

func (r *mysqlRepository) GetUserByEmail(email string) (*entities.User, error) {
	var user entities.User
	if err := r.db.Where("email = ?", email).First(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

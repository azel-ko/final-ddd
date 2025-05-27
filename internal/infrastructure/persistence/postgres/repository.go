// internal/infrastructure/persistence/postgres/repository.go
package postgres

import (
	"github.com/azel-ko/final-ddd/internal/domain/entities"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
	"gorm.io/gorm"
)

type postgresRepository struct {
	db *gorm.DB
}

func NewPostgresRepository(db *gorm.DB) repository.Repository {
	return &postgresRepository{db: db}
}

func (r *postgresRepository) CreateUser(user *entities.User) error {
	return r.db.Create(user).Error
}

func (r *postgresRepository) GetUser(id int) (*entities.User, error) {
	var user entities.User
	if err := r.db.First(&user, id).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *postgresRepository) UpdateUser(user *entities.User) error {
	return r.db.Save(user).Error
}

func (r *postgresRepository) DeleteUser(id int) error {
	return r.db.Delete(&entities.User{}, id).Error
}

// Other repository methods for User and Book...

func (r *postgresRepository) GetUserByEmail(email string) (*entities.User, error) {
	var user entities.User
	if err := r.db.Where("email = ?", email).First(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *postgresRepository) CreateBook(book *entities.Book) error {
	return r.db.Create(book).Error
}

func (r *postgresRepository) GetBook(id int) (*entities.Book, error) {
	var book entities.Book
	if err := r.db.First(&book, id).Error; err != nil {
		return nil, err
	}
	return &book, nil
}

func (r *postgresRepository) UpdateBook(book *entities.Book) error {
	return r.db.Save(book).Error
}

func (r *postgresRepository) DeleteBook(id int) error {
	return r.db.Delete(&entities.Book{}, id).Error
}

func (r *postgresRepository) GetBookByISBN(isbn string) (*entities.Book, error) {
	var book entities.Book
	if err := r.db.Where("isbn = ?", isbn).First(&book).Error; err != nil {
		return nil, err
	}
	return &book, nil
}

func (r *postgresRepository) ListBooks(offset, limit int, title, author string) ([]entities.Book, int64, error) {
	var books []entities.Book
	var total int64
	
	query := r.db.Model(&entities.Book{})
	
	if title != "" {
		query = query.Where("title ILIKE ?", "%"+title+"%")
	}
	
	if author != "" {
		query = query.Where("author ILIKE ?", "%"+author+"%")
	}
	
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	
	if err := query.Offset(offset).Limit(limit).Find(&books).Error; err != nil {
		return nil, 0, err
	}
	
	return books, total, nil
}

func (r *postgresRepository) UpdateUserProfile(user *entities.User) error {
	return r.db.Model(user).Updates(map[string]interface{}{
		"name":  user.Name,
		"email": user.Email,
	}).Error
}

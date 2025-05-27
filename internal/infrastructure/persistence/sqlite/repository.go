// internal/infrastructure/persistence/sqlite/repository.go
package sqlite

import (
	"github.com/azel-ko/final-ddd/internal/domain/entities"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
	"gorm.io/gorm"
)

type sqliteRepository struct {
	db *gorm.DB
}

func NewSQLiteRepository(db *gorm.DB) repository.Repository {
	return &sqliteRepository{db: db}
}

func (r *sqliteRepository) CreateUser(user *entities.User) error {
	return r.db.Create(user).Error
}

func (r *sqliteRepository) GetUser(id int) (*entities.User, error) {
	var user entities.User
	if err := r.db.First(&user, id).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *sqliteRepository) UpdateUser(user *entities.User) error {
	return r.db.Save(user).Error
}

func (r *sqliteRepository) DeleteUser(id int) error {
	return r.db.Delete(&entities.User{}, id).Error
}

func (r *sqliteRepository) GetUserByEmail(email string) (*entities.User, error) {
	var user entities.User
	if err := r.db.Where("email = ?", email).First(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *sqliteRepository) CreateBook(book *entities.Book) error {
	return r.db.Create(book).Error
}

func (r *sqliteRepository) GetBook(id int) (*entities.Book, error) {
	var book entities.Book
	if err := r.db.First(&book, id).Error; err != nil {
		return nil, err
	}
	return &book, nil
}

func (r *sqliteRepository) UpdateBook(book *entities.Book) error {
	return r.db.Save(book).Error
}

func (r *sqliteRepository) DeleteBook(id int) error {
	return r.db.Delete(&entities.Book{}, id).Error
}

func (r *sqliteRepository) GetBookByISBN(isbn string) (*entities.Book, error) {
	var book entities.Book
	if err := r.db.Where("isbn = ?", isbn).First(&book).Error; err != nil {
		return nil, err
	}
	return &book, nil
}

func (r *sqliteRepository) ListBooks(offset, limit int, title, author string) ([]entities.Book, int64, error) {
	var books []entities.Book
	var total int64
	
	query := r.db.Model(&entities.Book{})
	
	if title != "" {
		query = query.Where("title LIKE ?", "%"+title+"%")
	}
	
	if author != "" {
		query = query.Where("author LIKE ?", "%"+author+"%")
	}
	
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	
	if err := query.Offset(offset).Limit(limit).Find(&books).Error; err != nil {
		return nil, 0, err
	}
	
	return books, total, nil
}

func (r *sqliteRepository) UpdateUserProfile(user *entities.User) error {
	return r.db.Model(user).Updates(map[string]interface{}{
		"name":  user.Name,
		"email": user.Email,
	}).Error
}

package repository

import "github.com/azel-ko/final-ddd/internal/domain/entities"

type Repository interface {
	// User operations
	CreateUser(user *entities.User) error
	GetUser(id int) (*entities.User, error)
	UpdateUser(user *entities.User) error
	DeleteUser(id int) error
	GetUserByEmail(email string) (*entities.User, error)
	UpdateUserProfile(user *entities.User) error

	// Book operations
	CreateBook(book *entities.Book) error
	GetBook(id int) (*entities.Book, error)
	UpdateBook(book *entities.Book) error
	DeleteBook(id int) error
	GetBookByISBN(isbn string) (*entities.Book, error)
	ListBooks(offset, limit int, title, author string) ([]entities.Book, int64, error)
}

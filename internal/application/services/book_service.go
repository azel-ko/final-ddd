package services

import (
	"github.com/azel-ko/final-ddd/internal/application/dto"
	"github.com/azel-ko/final-ddd/internal/application/errors"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
)

type BookService struct {
	repo repository.Repository
}

func NewBookService(repo repository.Repository) *BookService {
	return &BookService{repo: repo}
}

func (s *BookService) CreateBook(req *dto.CreateBookRequest) (*dto.BookResponse, error) {
	if _, err := s.repo.GetBookByISBN(req.ISBN); err == nil {
		return nil, errors.ErrISBNAlreadyExists
	}

	book := dto.ToBookEntity(req)
	if err := s.repo.CreateBook(book); err != nil {
		return nil, err
	}

	return dto.ToBookResponse(book), nil
}

func (s *BookService) GetBookByISBN(isbn string) (*dto.BookResponse, error) {
	book, err := s.repo.GetBookByISBN(isbn)
	if err != nil {
		return nil, err
	}

	return dto.ToBookResponse(book), nil
}

func (s *BookService) GetBook(id int) (*dto.BookResponse, error) {
	book, err := s.repo.GetBook(id)
	if err != nil {
		return nil, errors.ErrNotFound
	}
	return dto.ToBookResponse(book), nil
}

func (s *BookService) UpdateBook(id int, req *dto.UpdateBookRequest) (*dto.BookResponse, error) {
	book, err := s.repo.GetBook(id)
	if err != nil {
		return nil, errors.ErrNotFound
	}

	book.ISBN = req.ISBN
	book.Title = req.Title
	book.Author = req.Author

	if err := s.repo.UpdateBook(book); err != nil {
		return nil, err
	}

	return dto.ToBookResponse(book), nil
}

func (s *BookService) DeleteBook(id int) error {
	return s.repo.DeleteBook(id)
}

func (s *BookService) ListBooks(page, pageSize int, title, author string) (*dto.PaginatedBookResponse, error) {
	offset := (page - 1) * pageSize
	books, total, err := s.repo.ListBooks(offset, pageSize, title, author)
	if err != nil {
		return nil, err // Consider wrapping error (e.g., errors.ErrDatabase)
	}

	bookResponses := dto.ToBookResponseList(books)
	return &dto.PaginatedBookResponse{
		Items: bookResponses,
		Total: total,
	}, nil
}

package dto

import "github.com/azel-ko/final-ddd/internal/domain/entities"

type CreateBookRequest struct {
	Title  string `json:"title" binding:"required"`
	Author string `json:"author" binding:"required"`
	ISBN   string `json:"isbn" binding:"required"`
}

type UpdateBookRequest struct {
	Title  string `json:"title" binding:"required"`
	Author string `json:"author" binding:"required"`
	ISBN   string `json:"isbn" binding:"required"`
}

type BookResponse struct {
	ID     uint   `json:"id"`
	Title  string `json:"title"`
	Author string `json:"author"`
	ISBN   string `json:"isbn"`
}

func ToBookEntity(req *CreateBookRequest) *entities.Book {
	return &entities.Book{
		Title:  req.Title,
		Author: req.Author,
		ISBN:   req.ISBN,
	}
}

func ToBookResponse(book *entities.Book) *BookResponse {
	return &BookResponse{
		ID:     book.ID,
		Title:  book.Title,
		Author: book.Author,
		ISBN:   book.ISBN,
	}
}

type PaginatedBookResponse struct {
	Items []BookResponse `json:"items"`
	Total int64          `json:"total"`
}

func ToBookResponseList(books []entities.Book) []BookResponse {
	bookResponses := make([]BookResponse, len(books))
	for i, book := range books {
		bookResponses[i] = *ToBookResponse(&book)
	}
	return bookResponses
}

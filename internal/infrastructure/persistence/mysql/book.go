package mysql

import "github.com/azel-ko/final-ddd/internal/domain/entities"

func (r *mysqlRepository) CreateBook(book *entities.Book) error {
	return r.db.Create(book).Error
}
func (r *mysqlRepository) GetBook(id int) (*entities.Book, error) {
	var book entities.Book
	if err := r.db.First(&book, id).Error; err != nil {
		return nil, err
	}
	return &book, nil
}

func (r *mysqlRepository) ListBooks(offset, limit int, title, author string) ([]entities.Book, int64, error) {
	var books []entities.Book
	var total int64

	query := r.db.Model(&entities.Book{})
	countQuery := r.db.Model(&entities.Book{})

	if title != "" {
		query = query.Where("title LIKE ?", "%"+title+"%")
		countQuery = countQuery.Where("title LIKE ?", "%"+title+"%")
	}
	if author != "" {
		query = query.Where("author LIKE ?", "%"+author+"%")
		countQuery = countQuery.Where("author LIKE ?", "%"+author+"%")
	}

	if err := countQuery.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Offset(offset).Limit(limit).Find(&books).Error; err != nil {
		return nil, 0, err
	}

	return books, total, nil
}
func (r *mysqlRepository) UpdateBook(book *entities.Book) error {
	return r.db.Save(book).Error
}
func (r *mysqlRepository) DeleteBook(id int) error {
	return r.db.Delete(&entities.Book{}, id).Error
}

func (r *mysqlRepository) GetBookByISBN(isbn string) (*entities.Book, error) {
	var book entities.Book
	if err := r.db.Where("isbn = ?", isbn).First(&book).Error; err != nil {
		return nil, err
	}
	return &book, nil
}

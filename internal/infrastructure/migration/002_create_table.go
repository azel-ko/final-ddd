package migration

import (
	"gorm.io/gorm"
	"time"
)

// BookTableMigration 创建图书表的迁移
type BookTableMigration struct{}

func (m *BookTableMigration) ID() string {
	return "002_create_books_table"
}

func (m *BookTableMigration) Up(db *gorm.DB) error {
	// 自动迁移表结构
	if err := db.AutoMigrate(&Book{}); err != nil {
		return err
	}

	// 插入默认数据
	books := []Book{
		{
			Title:  "The Catcher in the Rye",
			Author: "J.D. Salinger",
			ISBN:   "9780316769488",
		},
		{
			Title:  "To Kill a Mockingbird",
			Author: "Harper Lee",
			ISBN:   "9780061120084",
		},
		{
			Title:  "1984",
			Author: "George Orwell",
			ISBN:   "9780451524935",
		},
	}

	return db.Create(&books).Error
}

func (m *BookTableMigration) Down(db *gorm.DB) error {
	return db.Migrator().DropTable(&Book{})
}

// Book 定义图书表的结构
type Book struct {
	ID        uint      `gorm:"primarykey"`
	Title     string    `gorm:"size:255;not null"`
	Author    string    `gorm:"size:255;not null"`
	ISBN      string    `gorm:"size:20;not null;unique"`
	CreatedAt time.Time `gorm:"not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `gorm:"not null;default:CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"`
}

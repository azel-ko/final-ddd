package migration

import (
	"gorm.io/gorm"
	"time"
)

// UserTableMigration 创建用户表的迁移
type UserTableMigration struct{}

func (m *UserTableMigration) ID() string {
	return "002_create_users_table"
}

func (m *UserTableMigration) Up(db *gorm.DB) error {
	// 自动迁移表结构
	if err := db.AutoMigrate(&User{}); err != nil {
		return err
	}

	// 插入默认数据
	users := []User{
		{
			Name:      "Alice",
			Email:     "alice@example.com",
			Password:  "password123",
			Role:      "admin",
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		{
			Name:      "Bob",
			Email:     "bob@example.com",
			Password:  "password123",
			Role:      "user",
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
	}

	return db.Create(&users).Error
}

func (m *UserTableMigration) Down(db *gorm.DB) error {
	return db.Migrator().DropTable(&User{})
}

// User 定义用户表的结构
type User struct {
	ID        uint      `gorm:"primarykey"`
	Name      string    `gorm:"size:255;not null"`
	Email     string    `gorm:"size:255;not null;unique"`
	Password  string    `gorm:"size:255;not null"`
	Role      string    `gorm:"size:255;not null;default:'user'"`
	CreatedAt time.Time `gorm:"type:timestamp;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `gorm:"type:timestamp;not null;default:CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"`
}

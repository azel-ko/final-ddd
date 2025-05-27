package entities

import "time"

type User struct {
	ID       uint      `gorm:"primarykey"`
	Name     string    `gorm:"size:255;not null"`
	Email    string    `gorm:"size:255;not null;unique"`
	Password string    `gorm:"size:255;not null"`
	Role     string    `gorm:"size:255;not null"`
	CreatedAt time.Time `gorm:"autoCreateTime"`
}

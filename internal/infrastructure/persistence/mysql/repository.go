// internal/infrastructure/persistence/mysql/repository.go
package mysql

import (
	"github.com/azel-ko/final-ddd/internal/domain/repository"
	"gorm.io/gorm"
)

type mysqlRepository struct {
	db *gorm.DB
}

func NewMySQLRepository(db *gorm.DB) repository.Repository {
	return &mysqlRepository{db: db}
}

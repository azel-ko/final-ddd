package persistence

import (
	"fmt"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
	"github.com/azel-ko/final-ddd/internal/infrastructure/persistence/mysql"
	"github.com/azel-ko/final-ddd/internal/infrastructure/persistence/postgres"
	"github.com/azel-ko/final-ddd/internal/infrastructure/persistence/sqlite"
	"github.com/azel-ko/final-ddd/pkg/config"
	"github.com/azel-ko/final-ddd/pkg/logger"
	gorm_mysql "gorm.io/driver/mysql"
	gorm_postgres "gorm.io/driver/postgres"
	gorm_sqlite "gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func NewRepository(cfg *config.Config) (repository.Repository, *gorm.DB, error) {

	var db *gorm.DB
	var err error

	switch cfg.Database.Type {
	case "mysql":
		dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8mb4&parseTime=True&loc=Local",
			cfg.Database.User, cfg.Database.Password,
			cfg.Database.Host, cfg.Database.Port, cfg.Database.Name)
		db, err = gorm.Open(gorm_mysql.Open(dsn), &gorm.Config{})
	case "postgres":
		dsn := fmt.Sprintf("user=%s password=%s host=%s port=%d dbname=%s sslmode=disable",
			cfg.Database.User, cfg.Database.Password,
			cfg.Database.Host, cfg.Database.Port, cfg.Database.Name)
		db, err = gorm.Open(gorm_postgres.Open(dsn), &gorm.Config{})
	case "sqlite":
		dbPath := fmt.Sprintf("/%s/%s/%s.db", cfg.Database.Path, cfg.Database.Host, cfg.Database.Name) // 指定SQLite数据库文件路径
		db, err = gorm.Open(gorm_sqlite.Open(dbPath), &gorm.Config{})
	default:
		return nil, nil, fmt.Errorf("unsupported database type: %s", cfg.Database.Type)
	}

	if err != nil {
		return nil, nil, err
	}

	defer func() {
		if err == nil {
			logger.Info("Database setup completed")
		}
	}()

	switch cfg.Database.Type {
	case "mysql":
		return mysql.NewMySQLRepository(db), db, nil
	case "postgres":
		return postgres.NewPostgresRepository(db), db, nil
	case "sqlite":
		return sqlite.NewSQLiteRepository(db), db, nil
	default:
		return nil, nil, fmt.Errorf("unsupported database type: %s", cfg.Database.Type)
	}
}

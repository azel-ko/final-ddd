package persistence

import (
	"fmt"
	"github.com/azel-ko/final-ddd/internal/domain/repository"
	"github.com/azel-ko/final-ddd/internal/infrastructure/persistence/mysql"
	"github.com/azel-ko/final-ddd/internal/infrastructure/persistence/postgres"
	"github.com/azel-ko/final-ddd/internal/infrastructure/persistence/sqlite"
	"github.com/azel-ko/final-ddd/internal/pkg/config"
	"github.com/azel-ko/final-ddd/internal/pkg/logger"
	gorm_mysql "gorm.io/driver/mysql"
	gorm_postgres "gorm.io/driver/postgres"
	gorm_sqlite "gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func NewRepository(cfg *config.Config) (repository.Repository, *gorm.DB, error) {
	var db *gorm.DB
	var err error

	// 使用新的配置方法获取数据库连接字符串
	dbURL := cfg.Database.GetDatabaseURL()
	driverName := cfg.Database.GetDriverName()

	// PostgreSQL 优先的数据库连接
	switch driverName {
	case "postgres":
		db, err = gorm.Open(gorm_postgres.Open(dbURL), &gorm.Config{})
		if err != nil {
			return nil, nil, fmt.Errorf("failed to connect to PostgreSQL: %w", err)
		}
		
		// 配置连接池
		if sqlDB, err := db.DB(); err == nil {
			sqlDB.SetMaxOpenConns(cfg.Database.Pool.MaxOpen)
			sqlDB.SetMaxIdleConns(cfg.Database.Pool.MaxIdle)
			// 注意：MaxLifetime 需要解析时间字符串，这里简化处理
		}
		
		logger.Info("Connected to PostgreSQL database")
		return postgres.NewPostgresRepository(db), db, nil
		
	case "mysql":
		db, err = gorm.Open(gorm_mysql.Open(dbURL), &gorm.Config{})
		if err != nil {
			return nil, nil, fmt.Errorf("failed to connect to MySQL: %w", err)
		}
		logger.Info("Connected to MySQL database")
		return mysql.NewMySQLRepository(db), db, nil
		
	case "sqlite3":
		// SQLite 使用路径而不是 URL
		dbPath := cfg.Database.Path
		if dbPath == "" {
			dbPath = "./data/app.db"
		}
		db, err = gorm.Open(gorm_sqlite.Open(dbPath), &gorm.Config{})
		if err != nil {
			return nil, nil, fmt.Errorf("failed to connect to SQLite: %w", err)
		}
		logger.Info("Connected to SQLite database")
		return sqlite.NewSQLiteRepository(db), db, nil
		
	default:
		return nil, nil, fmt.Errorf("unsupported database driver: %s", driverName)
	}
}

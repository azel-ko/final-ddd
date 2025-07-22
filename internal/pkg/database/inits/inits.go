package inits

import (
	"fmt"
	"github.com/azel-ko/final-ddd/internal/pkg/config"
)

// DatabaseInitializer 定义了数据库初始化器接口
type DatabaseInitializer interface {
	Initialize() error
}

// NewDatabaseInitializer 工厂函数 - PostgreSQL 优先
func NewDatabaseInitializer(config *config.Config) (DatabaseInitializer, error) {
	// 优先检查是否为 PostgreSQL（默认和推荐）
	if config.Database.IsPostgreSQL() {
		return &PostgreSQLInitializer{config: config}, nil
	}
	
	// 向后兼容：检查旧的 type 字段
	switch config.Database.Type {
	case "mysql":
		return &MySQLInitializer{config: config}, nil
	case "sqlite":
		return &SQLiteInitializer{config: config}, nil
	case "postgres", "postgresql":
		return &PostgreSQLInitializer{config: config}, nil
	case "":
		// 如果没有指定类型，默认使用 PostgreSQL
		return &PostgreSQLInitializer{config: config}, nil
	default:
		return nil, fmt.Errorf("不支持的数据库类型: %s，支持的类型: postgres (默认), mysql, sqlite", config.Database.Type)
	}
}

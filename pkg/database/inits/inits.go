package inits

import (
	"fmt"
	"github.com/azel-ko/final-ddd/pkg/config"
)

// DatabaseInitializer 定义了数据库初始化器接口
type DatabaseInitializer interface {
	Initialize() error
}

// NewDatabaseInitializer 是一个工厂函数，根据数据库类型返回相应的初始化器
func NewDatabaseInitializer(config *config.Config) (DatabaseInitializer, error) {
	switch config.Database.Type {
	case "mysql":
		return &MySQLInitializer{config: config}, nil
	case "postgres":
		return &PostgreSQLInitializer{config: config}, nil
	case "sqlite":
		return &SQLiteInitializer{config: config}, nil
	default:
		return nil, fmt.Errorf("不支持的数据库类型: %s", config.Database.Type)
	}
}

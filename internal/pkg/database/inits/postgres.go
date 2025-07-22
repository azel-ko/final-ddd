package inits

import (
	"database/sql"
	"fmt"
	"github.com/azel-ko/final-ddd/internal/pkg/config"
)

// PostgreSQLInitializer 实现了 DatabaseInitializer 接口，用于 PostgreSQL 初始化
type PostgreSQLInitializer struct {
	config *config.Config
}

func (p *PostgreSQLInitializer) Initialize() error {
	// 使用新的配置方法获取连接信息
	dbURL := p.config.Database.GetDatabaseURL()
	
	// 构建没有特定数据库的DSN用于初始连接
	var initialDSN string
	if p.config.Database.URL != "" {
		// 如果使用 URL 配置，需要解析并修改数据库名
		initialDSN = fmt.Sprintf("host=%s port=%d user=%s password=%s sslmode=%s",
			p.config.Database.Host, p.config.Database.Port, 
			p.config.Database.User, p.config.Database.Password, p.config.Database.SSLMode)
	} else {
		// 使用分离字段配置
		sslMode := p.config.Database.SSLMode
		if sslMode == "" {
			sslMode = "disable"
		}
		initialDSN = fmt.Sprintf("host=%s port=%d user=%s password=%s sslmode=%s",
			p.config.Database.Host, p.config.Database.Port, 
			p.config.Database.User, p.config.Database.Password, sslMode)
	}

	// 尝试连接到 PostgreSQL 服务器（无特定数据库）
	db, err := sql.Open("postgres", initialDSN)
	if err != nil {
		return fmt.Errorf("无法打开 PostgreSQL 数据库连接: %v", err)
	}
	defer db.Close()

	// 测试连接是否成功
	if err = db.Ping(); err != nil {
		return fmt.Errorf("无法连接到 PostgreSQL 数据库服务器: %v", err)
	}

	// 检测数据库是否存在
	var exists bool
	err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM pg_catalog.pg_database WHERE datname=$1)", 
		p.config.Database.Name).Scan(&exists)
	if err != nil {
		return fmt.Errorf("查询 PostgreSQL 数据库存在性失败: %v", err)
	}

	if !exists {
		fmt.Printf("PostgreSQL 数据库 %s 不存在，正在创建...\n", p.config.Database.Name)
		_, err = db.Exec(fmt.Sprintf("CREATE DATABASE %s", p.config.Database.Name))
		if err != nil {
			return fmt.Errorf("创建 PostgreSQL 数据库失败: %v", err)
		}
		fmt.Printf("PostgreSQL 数据库 %s 创建成功\n", p.config.Database.Name)
	} else {
		fmt.Printf("PostgreSQL 数据库 %s 已存在\n", p.config.Database.Name)
	}

	return nil
}

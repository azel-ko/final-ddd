package inits

import (
	"database/sql"
	"fmt"
	"github.com/azel-ko/final-ddd/pkg/config"
)

// PostgreSQLInitializer 实现了 DatabaseInitializer 接口，用于 PostgreSQL 初始化
type PostgreSQLInitializer struct {
	config *config.Config
}

func (p *PostgreSQLInitializer) Initialize() error {
	// 构建没有特定数据库的DSN用于初始连接
	initialDSN := fmt.Sprintf("host=%s port=%d user=%s password=%s sslmode=disable",
		p.config.Database.Host, p.config.Database.Port, p.config.Database.User, p.config.Database.Password)

	// 尝试连接到 PostgreSQL 服务器（无特定数据库）
	db, err := sql.Open("postgres", initialDSN)
	if err != nil {
		return fmt.Errorf("无法打开 PostgreSQL 数据库连接: %v", err)
	}
	defer db.Close() // 确保临时连接在函数结束前关闭

	// 测试连接是否成功
	err = db.Ping()
	if err != nil {
		return fmt.Errorf("无法连接到 PostgreSQL 数据库服务器: %v", err)
	}

	// 检测数据库是否存在
	var exists bool
	err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM pg_catalog.pg_database WHERE datname=$1)", p.config.Database.Name).Scan(&exists)
	if err != nil {
		return fmt.Errorf("查询 PostgreSQL 数据库存在性失败: %v", err)
	}

	if !exists {
		fmt.Printf("PostgreSQL 数据库 %s 不存在，正在创建...\n", p.config.Database.Name)
		_, err = db.Exec(fmt.Sprintf("CREATE DATABASE %s", p.config.Database.Name))
		if err != nil {
			return fmt.Errorf("创建 PostgreSQL 数据库失败: %v", err)
		}
	} else {
		fmt.Printf("PostgreSQL 数据库 %s 已存在\n", p.config.Database.Name)
	}

	// 如果需要执行其他初始化 SQL 脚本或设置，可以在这里添加

	return nil
}

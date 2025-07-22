package inits

import (
	"database/sql"
	"fmt"
	"github.com/azel-ko/final-ddd/internal/pkg/config"
)

// MySQLInitializer 实现了 DatabaseInitializer 接口，用于 MySQL 初始化
type MySQLInitializer struct {
	config *config.Config
}

func (m *MySQLInitializer) Initialize() error {
	// 构建没有特定数据库的DSN用于初始连接
	initialDSN := fmt.Sprintf("%s:%s@tcp(%s:%d)/", m.config.Database.User, m.config.Database.Password, m.config.Database.Host, m.config.Database.Port)

	// 尝试连接到 MySQL 服务器（无特定数据库）
	db, err := sql.Open("mysql", initialDSN)
	if err != nil {
		return fmt.Errorf("无法打开 MySQL 数据库连接: %v", err)
	}
	defer db.Close() // 这个连接在函数结束前关闭

	// 检测数据库是否存在
	var exists bool
	err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ?)", m.config.Database.Name).Scan(&exists)
	if err != nil {
		return fmt.Errorf("查询 MySQL 数据库存在性失败: %v", err)
	}

	if !exists {
		fmt.Printf("MySQL 数据库 %s 不存在，正在创建...\n", m.config.Database.Name)
		_, err = db.Exec(fmt.Sprintf("CREATE DATABASE IF NOT EXISTS %s", m.config.Database.Name))
		if err != nil {
			return fmt.Errorf("创建 MySQL 数据库失败: %v", err)
		}
	} else {
		fmt.Printf("MySQL 数据库 %s 已存在\n", m.config.Database.Name)
	}

	// 如果需要执行其他初始化 SQL 脚本或设置，可以在这里添加

	return nil
}

package inits

import (
	"database/sql"
	"fmt"
	"github.com/azel-ko/final-ddd/internal/pkg/config"
)

// SQLiteInitializer 实现了 DatabaseInitializer 接口，用于 SQLite 初始化
type SQLiteInitializer struct {
	config *config.Config
}

func (s *SQLiteInitializer) Initialize() error {
	// SQLite 会在首次连接时自动创建文件，因此只需打开连接
	dbPath := s.config.Database.Path
	fmt.Printf("正在初始化 SQLite 数据库: %s\n", dbPath)

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return fmt.Errorf("无法打开 SQLite 数据库连接: %v", err)
	}
	defer db.Close() // 确保在函数结束前关闭数据库连接

	// 测试连接是否成功
	err = db.Ping()
	if err != nil {
		return fmt.Errorf("无法连接到 SQLite 数据库: %v", err)
	}

	// 如果需要执行其他初始化 SQL 脚本或设置，可以在这里添加
	// 例如，创建表结构、插入初始数据等

	fmt.Printf("SQLite 数据库 %s 初始化完成\n", dbPath)
	return nil
}

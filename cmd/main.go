package main

import (
	"fmt"
	"github.com/azel-ko/final-ddd/internal/infrastructure/cache"
	"github.com/azel-ko/final-ddd/internal/infrastructure/migration"
	"github.com/azel-ko/final-ddd/internal/infrastructure/persistence"
	"github.com/azel-ko/final-ddd/internal/interfaces/http/router"
	"github.com/azel-ko/final-ddd/pkg/config"
	migr "github.com/azel-ko/final-ddd/pkg/database/migration"
	"github.com/azel-ko/final-ddd/pkg/logger"
	"go.uber.org/zap"
	"log"
)

func main() {
	// 加载配置
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	logger.Init(cfg.Log.Level)

	// 初始化数据库连接
	repo, db, err := persistence.NewRepository(cfg)
	if err != nil {
		logger.Fatal("Failed to initialize repository", zap.Error(err))
	}

	// 运行迁移
	migrator := migr.NewMigrator(db)
	migration.RegisterMigrations(migrator)
	if err := migrator.Run(); err != nil {
		logger.Fatal("Failed to run migrations: %v", zap.Error(err))
	}

	// 初始化 Redis 缓存
	redisAddr := fmt.Sprintf("%s:%d", cfg.Redis.Host, cfg.Redis.Port)
	redisCache := cache.NewRedisCache(redisAddr, cfg.Redis.Password)

	// 设置路由
	r := router.Setup(cfg, repo, redisCache)

	// 启动服务器
	if err := r.Run(cfg.GetServerAddress()); err != nil {
		logger.Fatal("Failed to start server: %v", zap.Error(err))
	}
}

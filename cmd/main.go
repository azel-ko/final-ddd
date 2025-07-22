package main

import (
	"fmt"
	"log"
	"strings"

	"github.com/azel-ko/final-ddd/internal/infrastructure/cache"
	"github.com/azel-ko/final-ddd/internal/infrastructure/migration"
	"github.com/azel-ko/final-ddd/internal/infrastructure/persistence"
	"github.com/azel-ko/final-ddd/internal/interfaces/http/router"
	"github.com/azel-ko/final-ddd/internal/pkg/config"
	inits "github.com/azel-ko/final-ddd/internal/pkg/database/inits"
	migr "github.com/azel-ko/final-ddd/internal/pkg/database/migration"
	"github.com/azel-ko/final-ddd/internal/pkg/logger"
	"go.uber.org/zap"
)

func main() {
	// 加载配置 - PostgreSQL 优先
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// 初始化日志
	logger.Init(cfg.Log.Level)
	
	// 显示数据库配置信息
	logger.Info("Database configuration loaded",
		zap.String("driver", cfg.Database.GetDriverName()),
		zap.String("url", maskPassword(cfg.Database.GetDatabaseURL())),
		zap.Bool("is_postgresql", cfg.Database.IsPostgreSQL()),
	)

	// 根据数据库类型创建初始化器
	initr, err := inits.NewDatabaseInitializer(cfg)
	if err != nil {
		log.Fatalf("创建数据库初始化器失败: %v", err)
	}
	// 初始化数据库
	err = initr.Initialize()
	if err != nil {
		log.Fatalf("初始化数据库失败: %v", err)
	}
	strings.Fields("hello world")
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
// maskPassword 隐藏数据库 URL 中的密码信息
func maskPassword(url string) string {
	if strings.Contains(url, "://") {
		parts := strings.Split(url, "://")
		if len(parts) == 2 {
			protocol := parts[0]
			rest := parts[1]
			
			// 查找用户信息部分
			if strings.Contains(rest, "@") {
				userInfoAndHost := strings.Split(rest, "@")
				if len(userInfoAndHost) == 2 {
					userInfo := userInfoAndHost[0]
					hostAndPath := userInfoAndHost[1]
					
					// 隐藏密码
					if strings.Contains(userInfo, ":") {
						userParts := strings.Split(userInfo, ":")
						if len(userParts) >= 2 {
							return fmt.Sprintf("%s://%s:***@%s", protocol, userParts[0], hostAndPath)
						}
					}
				}
			}
		}
	}
	return url
}
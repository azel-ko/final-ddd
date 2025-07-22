package config

import (
	"fmt"
	"strings"
	"github.com/spf13/viper"
)

// Config 总配置结构
type Config struct {
	App      App            `mapstructure:"app"`
	Database DatabaseConfig `mapstructure:"database"`
	JWT      JWTConfig      `mapstructure:"jwt"`
	Redis    RedisConfig    `mapstructure:"redis"`
	Log      LogConfig      `mapstructure:"log"`
}

// App 应用配置
type App struct {
	Name string `mapstructure:"name"`
	Port int    `mapstructure:"port"`
	Env  string `mapstructure:"env"`
}

// DatabaseConfig 数据库配置 - PostgreSQL 优先
type DatabaseConfig struct {
	// PostgreSQL 主配置（默认和推荐）
	URL      string            `mapstructure:"url"`      // PostgreSQL 连接字符串
	Host     string            `mapstructure:"host"`     // PostgreSQL 主机
	Port     int               `mapstructure:"port"`     // PostgreSQL 端口
	Name     string            `mapstructure:"name"`     // 数据库名
	User     string            `mapstructure:"user"`     // 用户名
	Password string            `mapstructure:"password"` // 密码
	SSLMode  string            `mapstructure:"ssl_mode"` // SSL 模式
	Pool     DatabasePoolConfig `mapstructure:"pool"`    // 连接池配置
	
	// 向后兼容的类型字段（已弃用，但保留以支持旧配置）
	Type string `mapstructure:"type"` // 已弃用：使用 URL 或具体字段
	Path string `mapstructure:"path"` // 已弃用：仅用于 SQLite 兼容
	
	// 备用数据库配置（可选，用于测试或特殊场景）
	Fallback map[string]string `mapstructure:"fallback,omitempty"`
}

// DatabasePoolConfig 数据库连接池配置
type DatabasePoolConfig struct {
	MaxOpen     int    `mapstructure:"max_open"`     // 最大打开连接数
	MaxIdle     int    `mapstructure:"max_idle"`     // 最大空闲连接数
	MaxLifetime string `mapstructure:"max_lifetime"` // 连接最大生存时间
}

// JWTConfig JWT配置
type JWTConfig struct {
	Key string `mapstructure:"key"`
}

// RedisConfig Redis配置
type RedisConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
}

// LogConfig 日志配置
type LogConfig struct {
	Level  string `mapstructure:"level"`
	Format string `mapstructure:"format"`
}

var AppConfig Config

func Load() (*Config, error) {
	return LoadWithEnv("")
}

// LoadWithEnv 加载指定环境的配置
func LoadWithEnv(env string) (*Config, error) {
	// 设置基础配置
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("configs")
	viper.AutomaticEnv()

	// 读取基础配置文件
	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("failed to read base config: %w", err)
	}

	// 如果指定了环境，尝试加载环境特定配置
	if env == "" {
		env = viper.GetString("app.env")
	}
	
	if env != "" && env != "production" {
		envConfigPath := fmt.Sprintf("configs/environments/%s.yml", env)
		if err := mergeConfigFile(envConfigPath); err != nil {
			// 环境配置文件不存在不是错误，只是警告
			fmt.Printf("Warning: Environment config file %s not found, using base config\n", envConfigPath)
		}
	}

	// 解析配置到结构体
	if err := viper.Unmarshal(&AppConfig); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// 验证数据库配置
	if err := AppConfig.Database.ValidateConfig(); err != nil {
		return nil, fmt.Errorf("invalid database config: %w", err)
	}

	return &AppConfig, nil
}

// mergeConfigFile 合并环境特定的配置文件
func mergeConfigFile(configPath string) error {
	envViper := viper.New()
	envViper.SetConfigFile(configPath)
	envViper.AutomaticEnv()
	
	if err := envViper.ReadInConfig(); err != nil {
		return err
	}
	
	// 合并配置
	return viper.MergeConfigMap(envViper.AllSettings())
}

func (cfg *Config) GetServerAddress() string { return fmt.Sprintf(":%d", cfg.App.Port) }
// GetDatabaseURL 获取数据库连接字符串 - PostgreSQL 优先
func (cfg *DatabaseConfig) GetDatabaseURL() string {
	// 优先使用直接配置的 URL
	if cfg.URL != "" {
		return cfg.URL
	}
	
	// 如果没有 URL，构建 PostgreSQL 连接字符串（默认行为）
	if cfg.Host != "" && cfg.Name != "" {
		sslMode := cfg.SSLMode
		if sslMode == "" {
			sslMode = "disable" // 开发环境默认
		}
		
		return fmt.Sprintf("postgresql://%s:%s@%s:%d/%s?sslmode=%s",
			cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Name, sslMode)
	}
	
	// 向后兼容：检查旧的 type 字段
	if cfg.Type != "" {
		switch cfg.Type {
		case "postgres", "postgresql":
			return fmt.Sprintf("postgresql://%s:%s@%s:%d/%s?sslmode=disable",
				cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Name)
		case "mysql":
			return fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8mb4&parseTime=True&loc=Local",
				cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Name)
		case "sqlite":
			if cfg.Path != "" {
				return cfg.Path
			}
			return "./data/app.db"
		}
	}
	
	// 默认返回 PostgreSQL 本地连接
	return "postgresql://postgres:password@localhost:5432/final_ddd?sslmode=disable"
}

// IsPostgreSQL 检查是否使用 PostgreSQL
func (cfg *DatabaseConfig) IsPostgreSQL() bool {
	if cfg.URL != "" {
		return strings.HasPrefix(cfg.URL, "postgresql://") || strings.HasPrefix(cfg.URL, "postgres://")
	}
	
	// 默认假设是 PostgreSQL
	return cfg.Type == "" || cfg.Type == "postgres" || cfg.Type == "postgresql"
}

// GetDriverName 获取数据库驱动名称
func (cfg *DatabaseConfig) GetDriverName() string {
	if cfg.IsPostgreSQL() {
		return "postgres"
	}
	
	if cfg.Type == "mysql" {
		return "mysql"
	}
	
	if cfg.Type == "sqlite" {
		return "sqlite3"
	}
	
	// 默认返回 PostgreSQL
	return "postgres"
}

// ValidateConfig 验证配置
func (cfg *DatabaseConfig) ValidateConfig() error {
	// 如果有 URL，优先验证 URL
	if cfg.URL != "" {
		if !strings.Contains(cfg.URL, "://") {
			return fmt.Errorf("invalid database URL format")
		}
		return nil
	}
	
	// 验证基本字段
	if cfg.Host == "" {
		return fmt.Errorf("database host is required")
	}
	
	if cfg.Name == "" {
		return fmt.Errorf("database name is required")
	}
	
	if cfg.User == "" {
		return fmt.Errorf("database user is required")
	}
	
	return nil
}
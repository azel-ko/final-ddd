// pkg/database/migration/migration.go
package migration

import (
	"fmt"
	"github.com/azel-ko/final-ddd/internal/pkg/logger"
	"go.uber.org/zap"
	"gorm.io/gorm"
	"sort"
	"time"
)

// Migration 定义单个迁移
type Migration interface {
	ID() string             // 迁移的唯一标识，例如时间戳_名称
	Up(db *gorm.DB) error   // 升级操作
	Down(db *gorm.DB) error // 回滚操作
}

// Migrator 处理数据库迁移
type Migrator struct {
	db         *gorm.DB
	migrations []Migration
}

// SchemaMigration 迁移记录
type SchemaMigration struct {
	MigrationID string `gorm:"primaryKey"`
	AppliedAt   time.Time
}

// NewMigrator 创建新的迁移器
func NewMigrator(db *gorm.DB) *Migrator {
	return &Migrator{
		db:         db,
		migrations: make([]Migration, 0),
	}
}

// AddMigration 添加新的迁移
func (m *Migrator) AddMigration(migration Migration) {
	m.migrations = append(m.migrations, migration)
}

// ensureMigrationTable 确保迁移记录表存在
func (m *Migrator) ensureMigrationTable() error { return m.db.AutoMigrate(&SchemaMigration{}) }

// isApplied 检查迁移是否已经应用
func (m *Migrator) isApplied(migrationID string) (bool, error) {
	var count int64
	err := m.db.Model(&SchemaMigration{}).Where("migration_id = ?", migrationID).Count(&count).Error
	return count > 0, err
}

// Run 执行所有未应用的迁移
func (m *Migrator) Run() error {
	if err := m.ensureMigrationTable(); err != nil {
		return fmt.Errorf("failed to create migration table: %w", err)
	}

	// 按ID排序迁移
	sort.Slice(m.migrations, func(i, j int) bool {
		return m.migrations[i].ID() < m.migrations[j].ID()
	})

	// 执行迁移
	for _, migration := range m.migrations {
		applied, err := m.isApplied(migration.ID())
		if err != nil {
			return fmt.Errorf("failed to check migration status: %w", err)
		}

		if !applied {
			// 开始事务
			tx := m.db.Begin()
			if tx.Error != nil {
				return fmt.Errorf("failed to start transaction: %w", err)
			}

			// 执行迁移
			if err := migration.Up(tx); err != nil {
				tx.Rollback()
				return fmt.Errorf("failed to apply migration %s: %w", migration.ID(), err)
			}

			// 记录迁移
			if err = tx.Create(&SchemaMigration{MigrationID: migration.ID(), AppliedAt: time.Now()}).Error; err != nil {
				tx.Rollback()
				return fmt.Errorf("failed to record migration: %w", err)
			}

			// 提交事务
			if err = tx.Commit().Error; err != nil {
				return fmt.Errorf("failed to commit transaction: %w", err)
			}

			logger.Info("Applied migration", zap.String("ID", migration.ID()))
		}
	}
	logger.Info("migration setup completed")
	return nil
}

// internal/infrastructure/migration/migrations.go
package migration

import (
	baseMigration "github.com/azel-ko/final-ddd/pkg/database/migration"
)

// RegisterMigrations 注册所有迁移
func RegisterMigrations(migrator *baseMigration.Migrator) {
	migrator.AddMigration(&UserTableMigration{})
	migrator.AddMigration(&BookTableMigration{})
	// 在这里添加新的迁移
}

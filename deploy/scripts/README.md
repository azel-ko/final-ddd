# 部署脚本说明

本目录包含项目的所有脚本，统一管理构建和部署流程。

## 脚本列表

### 环境设置脚本
- `install-task.sh` - 安装 Task runner
- `install-k3s.sh` - 安装 k3s 集群
- `setup-cluster.sh` - 设置 k3s 集群（监控、证书管理等）

### 构建脚本
- `build.sh` - 统一构建脚本
  - 支持前端、后端、Docker 镜像构建
  - 支持并行构建和版本管理
  - 支持推送到镜像仓库

### 部署脚本
- `deploy.sh` - k3s 部署脚本
  - 支持多环境部署（dev/staging/prod）
  - 自动验证和健康检查
  - 部署状态监控

## 推荐使用方式

### 1. 使用 Task runner（推荐）
```bash
# 查看所有任务
task --list

# 完整环境设置
task setup

# 构建应用
task build:all

# 部署到开发环境
task deploy:dev
```

### 2. 直接使用脚本
```bash
# 安装环境
./deploy/scripts/install-k3s.sh
./deploy/scripts/setup-cluster.sh

# 构建应用
./deploy/scripts/build.sh --target all

# 部署应用
./deploy/scripts/deploy.sh --env dev
```

## 脚本特性

- **统一管理** - 所有脚本集中在一个目录
- **模块化设计** - 每个脚本职责单一
- **参数支持** - 支持命令行参数配置
- **错误处理** - 完善的错误检查和提示
- **多环境支持** - 支持开发、测试、生产环境
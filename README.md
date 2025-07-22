# Final-DDD

基于领域驱动设计（DDD）的全栈应用程序，前后端集成在一个二进制文件中。

## 项目特点

- 基于 Go 语言和 Gin 框架的后端 API
- 前端静态文件嵌入到 Go 二进制文件中
- 领域驱动设计（DDD）架构
- 支持多种数据库（MySQL, PostgreSQL, SQLite）
- 使用 pnpm 进行前端包管理
- Redis 缓存支持
- JWT 认证
- Prometheus 监控
- Docker 容器化部署
- k3s 轻量级 Kubernetes 部署支持

## 项目结构

```
.
├── cmd/                # 应用程序入口
├── configs/            # 配置文件
├── deploy/             # 部署相关配置
│   ├── scripts/        # 部署脚本
│   ├── k8s/            # Kubernetes 清单文件
│   │   ├── base/       # 基础配置
│   │   └── environments/ # 环境特定配置
│   └── docs/           # 部署文档
├── frontend/           # 前端应用程序
├── internal/           # 内部包
│   ├── application/    # 应用层
│   ├── domain/         # 领域层
│   ├── infrastructure/ # 基础设施层
│   └── interfaces/     # 接口层
├── pkg/                # 公共包
├── deploy/scripts/     # 部署和构建脚本
├── terraform/          # 基础设施即代码
└── Taskfile.yml       # Task runner 配置
```

## 开发环境设置

### 前提条件

- Go 1.23+
- Node.js 18+
- pnpm 10.6.2+ (前端包管理器)
- Docker (可选)
- Redis (可选，用于缓存)
- 数据库 (MySQL, PostgreSQL 或 SQLite)

### 本地开发

1. 安装 pnpm（如果尚未安装）

```bash
# 使用 npm 安装 pnpm
npm install -g pnpm

# 或者使用 corepack（Node.js 16.10+）
corepack enable
corepack prepare pnpm@latest --activate
```

2. 克隆仓库

```bash
git clone https://github.com/azel-ko/final-ddd.git
cd final-ddd
```

3. 安装依赖

```bash
# 后端依赖
go mod download

# 前端依赖（使用 pnpm）
cd frontend
pnpm install
cd ..
```

4. 构建前端

```bash
cd frontend
pnpm run build
cd ..
```

5. 复制前端构建文件到嵌入目录

```bash
mkdir -p internal/interfaces/http/router/frontend/dist
cp -r frontend/dist/* internal/interfaces/http/router/frontend/dist/
```

6. 运行应用程序

```bash
go run cmd/main.go
```

### 使用构建脚本

项目提供了一个自动化构建脚本，可以一键构建前后端：

```bash
./scripts/build.sh
```

构建完成后，可以直接运行生成的二进制文件：

```bash
./final-ddd
```

## 🚀 部署

本项目采用现代化的 k3s (轻量级 Kubernetes) 部署策略，提供完整的自动化部署解决方案。

### ⚡ 快速部署

#### 本地部署 (5分钟)
```bash
# 一键本地部署
make deploy-local

# 或者使用脚本
./deploy/scripts/k3s-deploy.sh --env dev --force-build
```

#### 远程部署
```bash
# 一键远程部署 (替换为您的服务器IP)
make deploy-remote HOST=192.168.1.100

# 或者使用脚本
./deploy/scripts/remote-deploy.sh --host 192.168.1.100 --all
```

### 📋 分步部署

#### 1. 环境准备
```bash
# 安装 k3s
./deploy/scripts/install-k3s.sh

# 设置集群组件
./deploy/scripts/setup-cluster.sh --env dev
```

#### 2. 应用部署
```bash
# 部署到开发环境
./deploy/scripts/k3s-deploy.sh --env dev

# 部署到生产环境
./deploy/scripts/k3s-deploy.sh --env prod --domain your-domain.com
```

#### 3. 验证部署
```bash
# 健康检查
./deploy/scripts/health-check.sh --env dev

# 访问应用
kubectl port-forward svc/final-ddd-backend-service 8080:8080 -n final-ddd-dev
```

### 🛠️ 部署脚本

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `k3s-deploy.sh` | 完整应用部署 | 主要部署脚本 |
| `remote-deploy.sh` | 远程部署 | 远程服务器部署 |
| `env-manager.sh` | 环境管理 | 环境生命周期管理 |
| `health-check.sh` | 健康检查 | 运维监控 |
| `rollback.sh` | 版本回滚 | 紧急回滚 |
| `remote-troubleshoot.sh` | 故障排除 | 问题诊断和修复 |

### 🌍 环境管理

```bash
# 创建环境
./deploy/scripts/env-manager.sh create --env staging

# 查看所有环境
./deploy/scripts/env-manager.sh list

# 销毁环境
./deploy/scripts/env-manager.sh destroy --env dev --force
```

### 📊 监控访问

```bash
# Grafana 仪表板
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# 访问: http://localhost:3000 (admin/admin123)

# Prometheus 指标
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# 访问: http://localhost:9090
```

### 服务架构

#### 单机模式架构：
```
Internet
    ↓
Traefik (host 网络模式)
    ↓
Final-DDD App
    ↓
PostgreSQL (localhost:5432)
```

#### 集群模式架构：
```
Internet
    ↓
Traefik (bridge 网络 + 服务发现)
    ↓
Final-DDD App (多实例)
    ↓
PostgreSQL (服务发现)
```

**模式选择：**
- **单机模式**: 适用于开发环境或单节点部署，使用 host 网络模式，性能更好
- **集群模式**: 适用于生产环境多节点部署，支持高可用和负载均衡

### 服务访问

- 应用主页: `https://${DOMAIN_NAME}`
- Traefik Dashboard: `http://traefik-server:8080`
- Kubernetes Dashboard: `https://kubernetes-dashboard`

### 添加新服务

要添加新服务（如 Redis），请参考：

1. 在 `deploy/k8s/base/` 目录中创建新的 Kubernetes 清单文件
2. 在 `deploy/k8s/environments/` 中添加环境特定配置
3. 更新部署脚本以包含新服务

### 故障排除

遇到问题请查看：[故障排除指南](deploy/docs/troubleshooting.md)

## 配置

应用程序使用 YAML 配置文件，位于 `configs` 目录中。可以通过环境变量覆盖配置项。

## 许可证

MIT

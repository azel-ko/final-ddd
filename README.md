# Final-DDD

基于领域驱动设计（DDD）的全栈应用程序，前后端集成在一个二进制文件中。

## 项目特点

- 基于 Go 语言和 Gin 框架的后端 API
- 前端静态文件嵌入到 Go 二进制文件中
- 领域驱动设计（DDD）架构
- 支持多种数据库（MySQL, PostgreSQL, SQLite）
- Redis 缓存支持
- JWT 认证
- Prometheus 监控
- Docker 容器化部署
- Nomad 集群部署支持

## 项目结构

```
.
├── cmd/                # 应用程序入口
├── configs/            # 配置文件
├── deploy/             # 部署相关配置 (新的部署目录)
│   ├── scripts/        # 部署脚本
│   ├── nomad/          # Nomad 作业定义
│   │   ├── infrastructure/  # 基础设施服务
│   │   └── applications/    # 应用服务
│   ├── configs/        # 环境配置
│   └── docs/           # 部署文档
├── frontend/           # 前端应用程序
├── internal/           # 内部包
│   ├── application/    # 应用层
│   ├── domain/         # 领域层
│   ├── infrastructure/ # 基础设施层
│   └── interfaces/     # 接口层
├── pkg/                # 公共包
├── scripts/            # 构建脚本
├── terraform/          # 基础设施即代码
└── Makefile           # 部署快捷命令
```

## 开发环境设置

### 前提条件

- Go 1.23+
- Node.js 18+
- Docker (可选)
- Redis (可选，用于缓存)
- 数据库 (MySQL, PostgreSQL 或 SQLite)

### 本地开发

1. 克隆仓库

```bash
git clone https://github.com/azel-ko/final-ddd.git
cd final-ddd
```

2. 安装依赖

```bash
# 后端依赖
go mod download

# 前端依赖
cd frontend
npm install
cd ..
```

3. 构建前端

```bash
cd frontend
npm run build
cd ..
```

4. 复制前端构建文件到嵌入目录

```bash
mkdir -p internal/interfaces/http/router/frontend/dist
cp -r frontend/dist/* internal/interfaces/http/router/frontend/dist/
```

5. 运行应用程序

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

## 部署

本项目使用 Nomad + Consul + Traefik 进行现代化容器编排部署。

### 快速开始

使用 Makefile 进行快速部署：

```bash
# 检查环境
make check

# 部署到开发环境（自动检测单机/集群模式）
make dev

# 强制使用单机模式部署
make dev CLUSTER_MODE=single

# 强制使用集群模式部署
make dev CLUSTER_MODE=cluster

# 部署到生产环境
make prod DOMAIN=your-domain.com

# 查看服务状态
make status

# 查看应用日志
make logs
```

### 环境搭建

首次部署前需要搭建 Nomad/Consul 环境，详见：[环境搭建指南](deploy/docs/setup.md)

### 部署脚本

项目提供了完整的部署脚本：

```bash
# 部署到开发环境（自动检测模式）
./deploy/scripts/deploy.sh --env dev

# 强制使用单机模式部署
./deploy/scripts/deploy.sh --env dev --cluster-mode single

# 强制使用集群模式部署
./deploy/scripts/deploy.sh --env dev --cluster-mode cluster

# 部署到生产环境并指定域名
./deploy/scripts/deploy.sh --env prod --domain your-domain.com

# 强制重新构建并异步部署
./deploy/scripts/deploy.sh --env dev --force-build --async
```

#### 部署参数

- `--env`: 部署环境 (dev|staging|prod)
- `--domain`: 应用程序域名
- `--cluster-mode`: 集群模式 (auto|single|cluster)
- `--force-build`: 强制重新构建镜像
- `--async`: 异步部署，不等待健康检查
- `--skip-infra`: 跳过基础设施部署
- `--nomad-addr`: Nomad 服务器地址
- `--consul-addr`: Consul 服务器地址

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
- Nomad UI: `http://nomad-server:4646`
- Consul UI: `http://consul-server:8500`

### 添加新服务

要添加新服务（如 Redis），请参考：

1. 复制 `deploy/nomad/infrastructure/redis.nomad.example` 为 `redis.nomad`
2. 在 `deploy/scripts/deploy.sh` 中添加部署逻辑
3. 在环境配置文件中添加相关环境变量

### 故障排除

遇到问题请查看：[故障排除指南](deploy/docs/troubleshooting.md)

## 配置

应用程序使用 YAML 配置文件，位于 `configs` 目录中。可以通过环境变量覆盖配置项。

## 许可证

MIT

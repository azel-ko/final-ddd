# 部署文档

本项目使用 Nomad + Consul + Traefik 进行服务编排和部署。

## 目录结构

```
deploy/
├── README.md                 # 部署文档
├── scripts/                  # 部署脚本
│   ├── deploy.sh            # 主部署脚本
│   ├── build.sh             # 构建脚本
│   └── cleanup.sh           # 清理脚本
├── nomad/                   # Nomad 作业定义
│   ├── infrastructure/      # 基础设施服务
│   │   ├── traefik.nomad   # 负载均衡器
│   │   ├── postgres.nomad  # 数据库
│   │   └── registry.nomad  # Docker 镜像仓库
│   └── applications/        # 应用服务
│       └── app.nomad       # 主应用
├── configs/                 # 配置文件模板
│   └── env/                # 环境变量配置
│       ├── dev.env         # 开发环境
│       ├── staging.env     # 测试环境
│       └── prod.env        # 生产环境
└── docs/                   # 部署相关文档
    ├── setup.md            # 环境搭建
    └── troubleshooting.md  # 故障排除
```

## 快速开始

### 1. 环境准备

确保已安装以下工具：
- Nomad
- Consul
- Docker
- Git

### 2. 部署基础设施

```bash
# 部署到开发环境（自动检测单机/集群模式）
./deploy/scripts/deploy.sh --env dev

# 强制使用单机模式
./deploy/scripts/deploy.sh --env dev --cluster-mode single

# 强制使用集群模式
./deploy/scripts/deploy.sh --env dev --cluster-mode cluster

# 部署到生产环境
./deploy/scripts/deploy.sh --env prod --domain your-domain.com
```

### 3. 添加新服务

1. 在 `deploy/nomad/applications/` 目录下创建新的 `.nomad` 文件
2. 在部署脚本中添加对应的部署逻辑
3. 运行部署脚本

## 环境变量

主要环境变量在 `deploy/configs/env/` 目录下配置：

- `DOMAIN_NAME`: 应用域名
- `DB_NAME`, `DB_USER`, `DB_PASSWORD`: 数据库配置
- `NOMAD_ADDR`: Nomad 集群地址
- `CONSUL_ADDR`: Consul 集群地址
- `POSTGRES_NODE_CLASS`: PostgreSQL 节点类别（集群模式）
- `REGISTRY_NODE_CLASS`: Registry 节点类别（集群模式）

## 集群模式说明

### 自动检测模式 (默认)
部署脚本会自动检测 Nomad 节点数量：
- 单节点: 自动使用单机模式配置
- 多节点: 自动使用集群模式配置

### 单机模式
- 使用 host 网络模式，性能更好
- 适用于开发环境或单节点部署
- 服务间通过 localhost 通信

### 集群模式
- 使用 bridge 网络模式和服务发现
- 支持多节点部署和高可用
- 可通过节点类别约束服务部署位置

## 服务访问

- 应用主页: `https://${DOMAIN_NAME}`
- Nomad UI: `http://nomad-server:4646`
- Consul UI: `http://consul-server:8500`
- Traefik Dashboard: `http://traefik-server:8080`

## 配置验证

在部署前可以验证 Nomad 配置文件：

```bash
# 验证所有配置文件
./deploy/scripts/validate-nomad.sh
```

## 故障排除

查看 `deploy/docs/troubleshooting.md` 获取常见问题解决方案。

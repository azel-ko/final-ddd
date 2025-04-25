# Nomad + Consul 部署指南

本指南将帮助您使用 Nomad 和 Consul 部署应用程序。

## 前提条件

- 已安装 Nomad（版本 1.0.0 或更高）
- 已安装 Consul（版本 1.9.0 或更高）
- 已安装 Docker
- 如果使用集群模式，需要有可用的 Docker 镜像仓库

## 部署架构

该部署方案使用以下组件：

- **Nomad**：用于编排和调度容器
- **Consul**：用于服务发现和健康检查
- **Traefik**：作为反向代理和负载均衡器
- **MySQL/PostgreSQL/SQLite**：数据库服务
- **Redis**：缓存服务
- **RabbitMQ**：消息队列服务
- **Prometheus + Grafana**：监控系统

## 单机部署

对于单机部署，您可以直接运行部署脚本：

```bash
./deploy.sh -d your-domain.com
```

## 集群部署

对于集群部署，您需要：

1. 确保 Nomad 和 Consul 集群已经正确配置
2. 确保所有 Nomad 客户端上都有必要的 Docker 卷
3. 使用 `--cluster` 参数运行部署脚本

```bash
./deploy.sh -d your-domain.com --cluster -n http://nomad-server:4646 -c http://consul-server:8500
```

### 异步部署

如果您希望加快部署速度，不等待每个服务的健康检查通过就继续部署下一个服务，可以使用 `--async` 参数：

```bash
./deploy.sh -d your-domain.com --cluster --async -n http://nomad-server:4646 -c http://consul-server:8500
```

这样，所有服务将在后台部署，脚本不会等待服务健康检查通过。您可以通过 Nomad UI 或命令行工具监控部署状态。

### 使用私有镜像仓库

如果您使用私有 Docker 镜像仓库，请设置 `DOCKER_REGISTRY` 环境变量：

```bash
export DOCKER_REGISTRY=your-registry.com
./deploy.sh -d your-domain.com --cluster
```

### 镜像拉取策略

所有服务的 Nomad 作业定义文件都配置了 `force_pull = false`，这告诉 Nomad 优先使用本地镜像，不要从远程仓库拉取镜像。这样可以加快部署速度，并减少对网络的依赖。

如果您需要强制从远程仓库拉取最新镜像，可以修改相应的 Nomad 作业定义文件，将 `force_pull` 设置为 `true`。

### 使用本地镜像仓库

如果您经常遇到网络问题或者需要在集群环境中共享镜像，可以使用内置的本地镜像仓库：

```bash
./deploy.sh -d your-domain.com --cluster --use-local-registry
```

这将首先部署一个本地 Docker Registry 服务，然后将镜像推送到这个本地仓库，最后使用本地仓库中的镜像部署其他服务。

本地镜像仓库的默认地址是 `registry.your-domain.com:5000`，您可以使用 `--registry-addr` 参数指定不同的地址：

```bash
./deploy.sh -d your-domain.com --cluster --use-local-registry --registry-addr registry.example.com:5000
```

#### Registry 数据存储

本地镜像仓库的数据存储在 Nomad 分配的目录中，您不需要手动创建任何目录。

#### 注意事项

使用本地镜像仓库时，您需要确保：

1. 所有 Nomad 客户端都能够访问这个仓库
2. 所有 Nomad 客户端上都有 `/var/lib/nomad/registry_data` 目录，并且有适当的权限
3. 如果仓库使用的是自签名证书，您可能需要在所有 Nomad 客户端上配置 Docker 信任这个证书

## DNS 配置

要使外部机器能够通过域名访问您的应用，您需要：

1. 确保您的域名 DNS 记录指向 Traefik 服务所在的节点 IP 地址
2. 如果使用多个节点运行 Traefik，请考虑使用外部负载均衡器

## 脚本参数

`deploy.sh` 脚本支持以下参数：

- `-h, --help`：显示帮助信息
- `-n, --nomad-addr ADDR`：设置 Nomad 地址（默认：http://localhost:4646）
- `-c, --consul-addr ADDR`：设置 Consul 地址（默认：http://localhost:8500）
- `-d, --domain DOMAIN`：设置应用域名（默认：example.com）
- `--cluster`：启用集群模式
- `--force-build`：强制重新构建镜像，即使本地已存在
- `--async`：异步部署模式，不等待服务健康检查通过就继续部署下一个服务
- `--wait-timeout SECONDS`：等待服务健康的超时时间（默认：60秒）
- `--use-local-registry`：使用本地镜像仓库
- `--registry-addr ADDR`：设置本地镜像仓库地址（默认：registry.DOMAIN_NAME:5000）
- `--database SERVICE`：设置数据库服务（mysql, postgres, sqlite）（默认：mysql）
- `--db-name NAME`：设置数据库名称（默认：app）
- `--db-user USER`：设置数据库用户（默认：user）
- `--db-password PASSWORD`：设置数据库密码（默认：password）

## 持久化存储

在集群环境中，您需要确保所有 Nomad 客户端上都有以下 Docker 卷：

- mysql_data
- postgres_data
- sqlite_data
- redis_data
- rabbitmq_data
- prometheus_data
- grafana_data
- traefik_logs
- app_log_data
- registry_data (如果使用本地镜像仓库)

对于生产环境，建议使用网络存储解决方案（如 NFS、Ceph 等）来确保数据的持久性和一致性。

## 安全注意事项

对于生产环境，您应该：

1. 启用 Consul 和 Nomad 的 ACL 系统
2. 使用 TLS 加密通信
3. 使用安全的密码和凭证
4. 限制对 Nomad 和 Consul API 的访问

## 故障排除

如果您遇到问题，请检查：

1. Nomad 和 Consul 日志
2. 容器日志
3. 网络连接和防火墙设置
4. DNS 配置

## 更多资源

- [Nomad 文档](https://www.nomadproject.io/docs)
- [Consul 文档](https://www.consul.io/docs)
- [Traefik 文档](https://doc.traefik.io/traefik/)

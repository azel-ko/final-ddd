# Design Document

## Overview

This design document outlines the comprehensive improvement of the project's deployment strategy, script management, configuration organization, and infrastructure components. The solution focuses on simplifying the current complex deployment setup while maintaining functionality and improving maintainability.

## Architecture

### Current State Analysis
- **Deployment**: Complex Nomad + Consul + Traefik setup with multiple orchestration layers
- **Scripts**: Scattered across `/scripts`, `/deploy/scripts` with overlapping functionality
- **Configuration**: Multiple database support with complex configuration hierarchy
- **Reverse Proxy**: Traefik with complex certificate management and routing

### Target Architecture
- **Deployment**: Simplified containerized deployment using Docker + systemd or Kubernetes
- **Scripts**: Unified script management through enhanced Makefile and consolidated script directory
- **Configuration**: PostgreSQL-first configuration with simplified structure
- **Reverse Proxy**: Nginx or Caddy for simpler configuration and better performance

## Components and Interfaces

### 1. Deployment Strategy Replacement

#### Option A: PM2 + Native Binary (Recommended for simplicity)
**PM2是什么**: PM2是一个生产级的进程管理器，专为Node.js应用设计但也支持其他语言（包括Go）

- **优点**:
  - 零停机重启和部署
  - 内置负载均衡器（集群模式）
  - 实时监控（CPU、内存使用率）
  - 日志管理和轮转
  - 自动重启崩溃的应用
  - 简单的配置文件（ecosystem.config.js）
  - 无容器开销，性能更好
  - 支持多环境部署

- **缺点**:
  - 主要为Node.js设计，Go支持有限
  - 单机部署，不支持多服务器集群
  - 依赖Node.js环境

- **组件**:
  - PM2进程管理器
  - 原生Go二进制文件
  - PM2配置文件
  - 简单的部署脚本

#### Option B: Lightweight Kubernetes (k3s)
**k3s是什么**: k3s是Rancher开发的轻量级Kubernetes发行版，专为边缘计算和资源受限环境设计

- **优点**:
  - 完整的Kubernetes功能，但资源占用少（<512MB）
  - 内置负载均衡、服务发现、存储
  - 支持多节点集群和高可用
  - 丰富的生态系统（Helm、Ingress等）
  - 自动SSL证书管理
  - 声明式配置（YAML）
  - 容器化部署，环境一致性好
  - 支持滚动更新和回滚

- **缺点**:
  - 学习曲线较陡峭
  - 配置相对复杂
  - 需要理解Kubernetes概念
  - 资源开销比直接部署大
  - 调试相对困难

- **组件**:
  - k3s集群
  - Kubernetes Deployments/Services
  - Ingress Controller（内置Traefik或可换成Nginx）
  - Helm Charts（可选）

#### Option C: Podman + systemd
- **Benefits**: Rootless containers, systemd integration, Docker-compatible
- **Components**:
  - Podman for container runtime (no daemon)
  - systemd for service management
  - Rootless operation for better security

#### Option D: Binary + systemd (Pure native)
- **Benefits**: Minimal overhead, direct system integration
- **Components**:
  - Native Go binary
  - systemd service files
  - Direct system integration
  - No container overhead

#### Option E: Ansible + Binary Deployment
- **Benefits**: Infrastructure as code, repeatable deployments
- **Components**:
  - Ansible playbooks for deployment automation
  - Native binary deployment
  - Configuration management
  - Multi-server deployment support

### 2. Script Consolidation (多种选择)

#### Option A: Task Runner + Makefile (推荐)
**Task Runner选择**:
- **Task (Go-based)**: 现代化的Make替代品，YAML配置，跨平台
- **Just**: 简单的命令运行器，类似Make但语法更现代
- **Mage (Go)**: Go编写的构建工具，类型安全

**结构**:
```
scripts/
├── Taskfile.yml          # Task配置文件
├── k8s/                  # k3s相关脚本
│   ├── deploy.sh
│   ├── rollback.sh
│   └── cleanup.sh
├── build/
│   ├── backend.sh
│   └── frontend.sh
└── dev/
    ├── setup.sh
    └── test.sh
```

#### Option B: 纯Makefile增强
- 使用Make的高级功能（函数、条件、并行）
- 环境变量管理
- 依赖关系优化

#### Option C: Shell脚本 + 配置文件
- 主控制脚本 + YAML/JSON配置
- 简单直接，易于理解
- 适合复杂的部署逻辑

### 3. Configuration Management (多种选择)

#### Option A: 分层配置 + PostgreSQL优先 (推荐k3s)
**配置管理工具选择**:
- **Viper (Go)**: 你已经在用，支持多种格式，环境变量覆盖
- **Kustomize**: k8s原生配置管理，支持环境覆盖
- **Helm**: k8s包管理器，模板化配置
- **ConfigMap + Secret**: k8s原生配置管理

**结构**:
```
configs/
├── base/                # 基础配置
│   ├── app.yml
│   └── database.yml
├── environments/        # 环境特定配置
│   ├── dev/
│   │   ├── kustomization.yml
│   │   └── patches.yml
│   ├── staging/
│   └── prod/
└── k8s/                # k8s配置
    ├── configmap.yml
    ├── secret.yml
    └── deployment.yml
```

#### Option B: 单文件配置 + 环境变量
- 简化为单个配置文件
- 大量使用环境变量
- 适合简单部署

#### Option C: 配置中心化
- **Consul KV**: 分布式配置存储
- **etcd**: k8s使用的键值存储
- **Vault**: 安全配置和密钥管理

**PostgreSQL优先配置示例**:
```yaml
# configs/base/app.yml
app:
  name: final-ddd
  port: 8080

database:
  # PostgreSQL作为默认和主要选择
  primary:
    driver: postgres
    url: ${DATABASE_URL:postgresql://postgres:password@postgres:5432/final_ddd}
    pool:
      max_open: 25
      max_idle: 5
  
  # 保留其他数据库支持但标记为legacy
  legacy:
    mysql:
      enabled: false
      url: ${MYSQL_URL:}
    sqlite:
      enabled: false
      path: ${SQLITE_PATH:./data/app.db}
```

### 4. Reverse Proxy Replacement (多种选择)

#### Option A: k3s内置Traefik (推荐，简化配置)
**为什么k3s的Traefik更简单**:
- k3s内置Traefik，无需复杂安装配置
- 使用Kubernetes Ingress资源，比传统Traefik配置文件简单
- 自动服务发现，无需手动配置后端
- 内置Let's Encrypt支持

**简化的Traefik配置示例**:
```yaml
# 只需要定义Ingress，Traefik自动处理
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.tls.certresolver: "letsencrypt"
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: app-tls
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 8080
```

**优点**:
- 你已有Traefik基础，学习成本低
- k8s版本配置比传统配置文件简单得多
- 与k8s原生集成，自动服务发现
- 内置监控指标暴露

#### Option B: 外部Nginx (传统方案)
- **优点**: 成熟稳定，配置灵活，性能优秀
- **缺点**: 需要手动配置，与k8s集成度低
- **适用**: 如果你对Nginx很熟悉

#### Option C: Caddy (自动化程度高)
- **优点**: 自动HTTPS，配置简单，现代化
- **缺点**: 相对较新，生态系统小
- **特色**: 零配置SSL，自动续期

#### Option D: Envoy Proxy (云原生)
- **优点**: 现代化，功能强大，可观测性好
- **缺点**: 配置复杂，学习曲线陡
- **适用**: 需要高级功能（限流、熔断等）

#### Option E: 云服务负载均衡器
- **AWS ALB/NLB**: 如果部署在AWS
- **Cloudflare**: 全球CDN + 负载均衡
- **优点**: 托管服务，无需维护
- **缺点**: 供应商锁定，成本较高

**推荐组合（k3s环境）**:
```yaml
# 使用Nginx Ingress替换默认Traefik
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
data:
  proxy-body-size: "50m"
  ssl-protocols: "TLSv1.2 TLSv1.3"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: app-tls
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 8080
```

## Data Models

### Configuration Schema
```go
type Config struct {
    App      AppConfig      `yaml:"app"`
    Database DatabaseConfig `yaml:"database"`
    Services ServicesConfig `yaml:"services"`
    Security SecurityConfig `yaml:"security"`
}

type DatabaseConfig struct {
    URL      string            `yaml:"url"`
    Fallback map[string]string `yaml:"fallback,omitempty"`
    Pool     PoolConfig        `yaml:"pool"`
}

type DeploymentConfig struct {
    Strategy string            `yaml:"strategy"` // docker, k3s
    Replicas int              `yaml:"replicas"`
    Resources ResourceLimits  `yaml:"resources"`
}
```

### Script Configuration
```yaml
# scripts/config.yml
scripts:
  build:
    parallel: true
    cache: true
  deploy:
    strategy: "docker" # docker, k3s
    environments: ["dev", "staging", "prod"]
  monitoring:
    health_check_interval: 30s
    log_retention: "7d"
```

## Error Handling

### Deployment Error Handling
- **Rollback Strategy**: Automatic rollback on deployment failure
- **Health Checks**: Comprehensive health checks before marking deployment successful
- **Logging**: Structured logging for all deployment operations
- **Notifications**: Optional webhook notifications for deployment status

### Configuration Error Handling
- **Validation**: Schema validation for all configuration files
- **Fallbacks**: Graceful fallback to default values
- **Environment Checks**: Pre-deployment environment validation

### Script Error Handling
- **Exit Codes**: Consistent exit codes across all scripts
- **Error Messages**: Clear, actionable error messages
- **Cleanup**: Automatic cleanup on script failure
- **Retry Logic**: Configurable retry logic for network operations

## Testing Strategy

### Deployment Testing
- **Local Testing**: Docker Compose setup for local development
- **Integration Tests**: Automated tests for deployment scripts
- **Smoke Tests**: Post-deployment health checks
- **Rollback Tests**: Automated rollback testing

### Configuration Testing
- **Schema Validation**: Automated validation of configuration files
- **Environment Testing**: Test configuration loading in different environments
- **Migration Testing**: Test database configuration migration

### Script Testing
- **Unit Tests**: Test individual script functions
- **Integration Tests**: Test script interactions
- **Performance Tests**: Test script execution time and resource usage

## Migration Plan

### Phase 1: Script Consolidation
1. Create new unified script structure
2. Migrate existing functionality
3. Update Makefile with new targets
4. Test all script operations

### Phase 2: Configuration Simplification
1. Create new configuration schema
2. Migrate existing configurations
3. Update application to use new config structure
4. Test configuration loading

### Phase 3: Deployment Strategy Migration
1. Choose deployment strategy (Docker + systemd recommended)
2. Create new deployment configurations
3. Set up parallel deployment environment
4. Migrate services one by one
5. Decommission old Nomad setup

### Phase 4: Reverse Proxy Migration
1. Choose reverse proxy solution (Nginx recommended)
2. Create new proxy configurations
3. Set up parallel proxy environment
4. Migrate traffic gradually
5. Decommission Traefik

## Implementation Considerations

### Backward Compatibility
- Maintain support for existing environment variables
- Provide migration scripts for configuration
- Document breaking changes clearly

### Performance
- Optimize Docker image sizes
- Use multi-stage builds
- Implement proper caching strategies
- Monitor resource usage

### Security
- Implement proper secret management
- Use least privilege principles
- Regular security updates
- SSL/TLS best practices

### Monitoring Components Configuration Management

#### 监控组件统一管理方案

**当前监控组件分析**:
- Grafana: 仪表板和可视化
- Prometheus: 指标收集和存储
- 可能的日志组件: Loki, ELK等

**k3s环境下的监控配置管理**:

##### Option A: Helm Charts管理 (推荐)
```yaml
# monitoring/values.yml - 统一配置文件
prometheus:
  enabled: true
  retention: "15d"
  storage: "10Gi"
  
grafana:
  enabled: true
  admin:
    password: ${GRAFANA_PASSWORD}
  persistence:
    enabled: true
    size: "1Gi"
  
loki:
  enabled: true
  retention: "7d"
```

**部署命令**:
```bash
# 一键部署所有监控组件
helm install monitoring ./monitoring/charts -f monitoring/values.yml
```

##### Option B: Kustomize管理
```
monitoring/
├── base/
│   ├── prometheus/
│   │   ├── deployment.yml
│   │   ├── configmap.yml
│   │   └── service.yml
│   ├── grafana/
│   │   ├── deployment.yml
│   │   ├── configmap.yml
│   │   └── pvc.yml
│   └── kustomization.yml
├── environments/
│   ├── dev/
│   │   ├── kustomization.yml
│   │   └── patches.yml
│   └── prod/
│       ├── kustomization.yml
│       └── patches.yml
```

##### Option C: ConfigMap + Secret分离管理
```yaml
# monitoring-config.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'app'
      static_configs:
      - targets: ['app-service:8080']
  
  grafana.ini: |
    [server]
    http_port = 3000
    [security]
    admin_user = admin
---
apiVersion: v1
kind: Secret
metadata:
  name: monitoring-secrets
data:
  grafana-password: ${GRAFANA_PASSWORD_BASE64}
  prometheus-auth: ${PROMETHEUS_AUTH_BASE64}
```

#### 监控配置的环境差异化管理

**开发环境**:
- 短期数据保留（3天）
- 简化的仪表板
- 本地存储

**生产环境**:
- 长期数据保留（30天）
- 完整的告警规则
- 持久化存储

**配置示例**:
```yaml
# environments/prod/monitoring-patch.yml
- op: replace
  path: /spec/template/spec/containers/0/env/0/value
  value: "30d"  # 生产环境保留30天数据

- op: add
  path: /spec/template/spec/containers/0/resources
  value:
    requests:
      memory: "2Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "1000m"
```

#### 监控组件的服务发现配置

**Prometheus自动发现k8s服务**:
```yaml
# prometheus-config.yml
scrape_configs:
- job_name: 'kubernetes-pods'
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: true
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
    action: replace
    target_label: __metrics_path__
    regex: (.+)
```

**Grafana数据源自动配置**:
```yaml
# grafana-datasources.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
data:
  datasources.yml: |
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-service:9090
      access: proxy
      isDefault: true
    - name: Loki
      type: loki
      url: http://loki-service:3100
      access: proxy
```

### 统一监控配置管理的优势

1. **版本控制**: 所有监控配置都在Git中管理
2. **环境一致性**: 通过Kustomize或Helm确保环境配置一致
3. **自动化部署**: 一条命令部署所有监控组件
4. **配置验证**: k8s原生的配置验证
5. **回滚能力**: 可以快速回滚到之前的监控配置

### 监控配置的最佳实践

- **密钥管理**: 使用k8s Secret管理敏感信息
- **资源限制**: 为每个监控组件设置合理的资源限制
- **数据持久化**: 重要数据使用PVC持久化存储
- **网络策略**: 使用NetworkPolicy限制监控组件间的网络访问
- **备份策略**: 定期备份Grafana仪表板和Prometheus数据
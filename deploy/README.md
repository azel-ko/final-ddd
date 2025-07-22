# Final DDD 部署指南

本文档提供了 Final DDD 应用的完整部署指南，基于 k3s (轻量级 Kubernetes) 部署策略。

## 目录

- [概述](#概述)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [部署选项](#部署选项)
- [环境管理](#环境管理)
- [监控和日志](#监控和日志)
- [故障排除](#故障排除)
- [最佳实践](#最佳实践)

## 概述

Final DDD 使用现代化的容器化部署策略：

- **容器编排**: k3s (轻量级 Kubernetes)
- **数据库**: PostgreSQL (默认)
- **缓存**: Redis
- **反向代理**: Traefik (k3s 内置)
- **监控**: Prometheus + Grafana + Loki
- **部署方式**: 本地部署 + 远程部署

## 系统要求

### 最低要求
- **CPU**: 2 核心
- **内存**: 2GB RAM
- **磁盘**: 20GB 可用空间
- **操作系统**: Linux (Ubuntu 18.04+, CentOS 7+, Debian 9+)

### 推荐配置
- **CPU**: 4 核心
- **内存**: 4GB RAM
- **磁盘**: 50GB SSD
- **网络**: 稳定的互联网连接

### 软件依赖
- Docker 20.10+
- kubectl
- Helm 3.0+
- Git

## 快速开始

### 1. 本地部署 (单机)

```bash
# 1. 安装 k3s
./deploy/scripts/install-k3s.sh

# 2. 设置集群组件
./deploy/scripts/setup-cluster.sh

# 3. 部署应用
./deploy/scripts/k3s-deploy.sh --env dev --force-build

# 4. 验证部署
./deploy/scripts/health-check.sh --env dev
```

### 2. 远程部署

```bash
# 1. 准备远程服务器
./deploy/scripts/setup-remote-test.sh --host <server-ip> --all

# 2. 执行远程部署
./deploy/scripts/remote-deploy.sh --host <server-ip> --all

# 3. 远程健康检查
./deploy/scripts/remote-troubleshoot.sh diagnose --host <server-ip>
```

## 部署选项

### 环境类型

#### 开发环境 (dev)
```bash
./deploy/scripts/k3s-deploy.sh --env dev
```
- 资源使用较少
- 调试模式开启
- 数据不持久化

#### 测试环境 (staging)
```bash
./deploy/scripts/k3s-deploy.sh --env staging
```
- 中等资源配置
- 接近生产环境
- 数据持久化

#### 生产环境 (prod)
```bash
./deploy/scripts/k3s-deploy.sh --env prod --domain your-domain.com
```
- 完整资源配置
- 高可用设置
- 完整监控和备份### 
部署脚本说明

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `install-k3s.sh` | 安装 k3s 集群 | 初始环境设置 |
| `setup-cluster.sh` | 配置集群组件 | 集群初始化 |
| `k3s-deploy.sh` | 完整应用部署 | 主要部署脚本 |
| `remote-deploy.sh` | 远程部署 | 远程服务器部署 |
| `env-manager.sh` | 环境管理 | 环境生命周期管理 |
| `health-check.sh` | 健康检查 | 运维监控 |
| `rollback.sh` | 版本回滚 | 紧急回滚 |

## 环境管理

### 创建环境
```bash
# 创建开发环境
./deploy/scripts/env-manager.sh create --env dev

# 创建生产环境
./deploy/scripts/env-manager.sh create --env prod
```

### 查看环境
```bash
# 列出所有环境
./deploy/scripts/env-manager.sh list

# 查看特定环境状态
./deploy/scripts/env-manager.sh status --env dev
```

### 管理环境
```bash
# 重置环境
./deploy/scripts/env-manager.sh reset --env dev

# 备份环境
./deploy/scripts/env-manager.sh backup --env prod

# 销毁环境
./deploy/scripts/env-manager.sh destroy --env dev --force
```

## 监控和日志

### 访问监控界面

#### Grafana (仪表板)
```bash
# 启动端口转发
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 访问地址: http://localhost:3000
# 默认用户名: admin
# 默认密码: admin123
```

#### Prometheus (指标)
```bash
# 启动端口转发
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# 访问地址: http://localhost:9090
```

### 日志查看
```bash
# 查看应用日志
kubectl logs -f -l app=final-ddd -n final-ddd-dev

# 查看特定 Pod 日志
kubectl logs -f <pod-name> -n final-ddd-dev

# 查看系统事件
kubectl get events -n final-ddd-dev --sort-by='.lastTimestamp'
```

## 故障排除

### 常见问题

#### 1. Pod 无法启动
```bash
# 检查 Pod 状态
kubectl get pods -n final-ddd-dev

# 查看 Pod 详细信息
kubectl describe pod <pod-name> -n final-ddd-dev

# 查看 Pod 日志
kubectl logs <pod-name> -n final-ddd-dev
```

#### 2. 服务无法访问
```bash
# 检查服务状态
kubectl get services -n final-ddd-dev

# 检查端点
kubectl get endpoints -n final-ddd-dev

# 端口转发测试
kubectl port-forward svc/final-ddd-backend-service 8080:8080 -n final-ddd-dev
```

#### 3. 数据库连接问题
```bash
# 检查数据库 Pod
kubectl get pods -l app=postgres -n final-ddd-dev

# 测试数据库连接
kubectl exec -it <postgres-pod> -n final-ddd-dev -- psql -U postgres -d final_ddd
```

### 远程故障排除
```bash
# 全面系统诊断
./deploy/scripts/remote-troubleshoot.sh diagnose --host <server-ip>

# 收集日志
./deploy/scripts/remote-troubleshoot.sh logs --host <server-ip> --lines 200

# 检查服务状态
./deploy/scripts/remote-troubleshoot.sh status --host <server-ip>

# 重启服务
./deploy/scripts/remote-troubleshoot.sh restart --host <server-ip>

# 自动修复常见问题
./deploy/scripts/remote-troubleshoot.sh fix-common --host <server-ip> --auto-fix
```

## 最佳实践

### 安全性
1. **使用 SSH 密钥认证**
   ```bash
   ./deploy/scripts/remote-deploy.sh --host <server> --key ~/.ssh/id_rsa
   ```

2. **定期更新密钥**
   ```bash
   kubectl create secret generic app-secrets \
     --from-literal=jwt-secret="$(openssl rand -base64 64)" \
     --namespace=final-ddd-prod --dry-run=client -o yaml | kubectl apply -f -
   ```

3. **网络策略**
   ```bash
   kubectl apply -f deploy/k8s/base/network-policy.yaml -n final-ddd-prod
   ```

### 备份策略
1. **数据库备份**
   ```bash
   # 手动备份
   kubectl exec -it <postgres-pod> -n final-ddd-prod -- \
     pg_dump -U postgres final_ddd > backup-$(date +%Y%m%d).sql
   
   # 自动备份 (CronJob 已配置)
   kubectl get cronjob database-backup -n final-ddd-prod
   ```

2. **配置备份**
   ```bash
   ./deploy/scripts/env-manager.sh backup --env prod
   ```

### 监控告警
1. **设置告警规则**
   - CPU 使用率 > 80%
   - 内存使用率 > 90%
   - 磁盘使用率 > 85%
   - 应用响应时间 > 500ms

2. **健康检查**
   ```bash
   # 持续监控
   ./deploy/scripts/health-check.sh --env prod --continuous --interval 60
   ```

### 性能优化
1. **资源限制**
   ```yaml
   resources:
     requests:
       memory: "256Mi"
       cpu: "250m"
     limits:
       memory: "1Gi"
       cpu: "1000m"
   ```

2. **水平扩展**
   ```bash
   kubectl scale deployment final-ddd-app --replicas=3 -n final-ddd-prod
   ```

## 高级配置

### 自定义域名
```bash
# 部署时指定域名
./deploy/scripts/k3s-deploy.sh --env prod --domain your-domain.com

# 手动配置 Ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: final-ddd-ingress
  namespace: final-ddd-prod
  annotations:
    traefik.ingress.kubernetes.io/router.tls.certresolver: "letsencrypt"
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: final-ddd-tls
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: final-ddd-backend-service
            port:
              number: 8080
EOF
```

### 多节点集群
```bash
# 主节点
./deploy/scripts/install-k3s.sh --mode server

# 工作节点
./deploy/scripts/install-k3s.sh --mode agent --server-ip <master-ip> --token <token>
```

### 外部数据库
```bash
# 使用外部 PostgreSQL
kubectl create secret generic app-secrets \
  --from-literal=database-url="postgresql://user:pass@external-db:5432/final_ddd" \
  --namespace=final-ddd-prod
```

## 版本管理

### 部署新版本
```bash
# 构建新镜像
./deploy/scripts/k3s-deploy.sh --env prod --force-build

# 查看部署历史
kubectl rollout history deployment/final-ddd-app -n final-ddd-prod
```

### 回滚版本
```bash
# 回滚到上一版本
./deploy/scripts/rollback.sh --env prod

# 回滚到指定版本
./deploy/scripts/rollback.sh --env prod --revision 3
```

## 支持和帮助

### 获取帮助
```bash
# 查看脚本帮助
./deploy/scripts/k3s-deploy.sh --help
./deploy/scripts/remote-deploy.sh --help
./deploy/scripts/env-manager.sh --help
```

### 常用命令
```bash
# 查看集群状态
kubectl get nodes
kubectl get all --all-namespaces

# 查看资源使用
kubectl top nodes
kubectl top pods --all-namespaces

# 查看事件
kubectl get events --sort-by='.lastTimestamp' --all-namespaces
```

### 联系支持
- 查看日志文件
- 运行诊断脚本
- 收集系统信息
- 提供错误详情

---

**注意**: 本文档基于 k3s 部署策略。如需其他部署方式，请参考相应的部署脚本和配置文件。
# Final DDD 快速开始指南

本指南帮助您在 5 分钟内快速部署 Final DDD 应用。

## 🚀 一键部署 (推荐)

### 本地部署
```bash
# 克隆项目
git clone <repository-url>
cd final-ddd

# 一键本地部署
make deploy-local
```

### 远程部署
```bash
# 一键远程部署 (替换为您的服务器IP)
make deploy-remote HOST=192.168.1.100
```

## 📋 分步部署

### 步骤 1: 环境准备
```bash
# 检查系统要求
./deploy/scripts/setup-remote-test.sh --host localhost --check-only

# 安装依赖 (如果需要)
./deploy/scripts/setup-remote-test.sh --host localhost --install-deps --setup-docker
```

### 步骤 2: 安装 k3s
```bash
# 安装单节点 k3s
./deploy/scripts/install-k3s.sh

# 验证安装
kubectl get nodes
```

### 步骤 3: 设置集群
```bash
# 设置集群组件 (监控、证书管理等)
./deploy/scripts/setup-cluster.sh --env dev

# 验证组件
kubectl get pods --all-namespaces
```

### 步骤 4: 部署应用
```bash
# 部署到开发环境
./deploy/scripts/k3s-deploy.sh --env dev --force-build

# 等待部署完成
kubectl wait --for=condition=available deployment/final-ddd-app -n final-ddd-dev --timeout=300s
```

### 步骤 5: 验证部署
```bash
# 健康检查
./deploy/scripts/health-check.sh --env dev

# 访问应用
kubectl port-forward svc/final-ddd-backend-service 8080:8080 -n final-ddd-dev
# 打开浏览器访问: http://localhost:8080
```

## 🔧 常用命令

### 查看状态
```bash
# 查看所有环境
./deploy/scripts/env-manager.sh list

# 查看特定环境状态
kubectl get all -n final-ddd-dev
```

### 查看日志
```bash
# 应用日志
kubectl logs -f -l app=final-ddd -n final-ddd-dev

# 数据库日志
kubectl logs -f -l app=postgres -n final-ddd-dev
```

### 访问服务
```bash
# 应用服务
kubectl port-forward svc/final-ddd-backend-service 8080:8080 -n final-ddd-dev

# Grafana 监控
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Prometheus 指标
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

## 🛠️ 故障排除

### 常见问题

#### Pod 无法启动
```bash
# 查看 Pod 状态
kubectl get pods -n final-ddd-dev

# 查看详细信息
kubectl describe pod <pod-name> -n final-ddd-dev
```

#### 服务无法访问
```bash
# 检查服务
kubectl get svc -n final-ddd-dev

# 测试连接
kubectl port-forward svc/final-ddd-backend-service 8080:8080 -n final-ddd-dev
```

#### 数据库连接失败
```bash
# 检查数据库状态
kubectl get pods -l app=postgres -n final-ddd-dev

# 测试数据库连接
kubectl exec -it <postgres-pod> -n final-ddd-dev -- psql -U postgres -d final_ddd
```

### 自动诊断
```bash
# 运行诊断脚本
./deploy/scripts/health-check.sh --env dev --detailed

# 自动修复常见问题
./deploy/scripts/remote-troubleshoot.sh fix-common --host localhost --auto-fix
```

## 🌐 远程部署

### 准备远程服务器
```bash
# 检查远程服务器 (替换为您的服务器IP)
./deploy/scripts/setup-remote-test.sh --host 192.168.1.100 --check-only

# 设置远程服务器
./deploy/scripts/setup-remote-test.sh --host 192.168.1.100 --all
```

### 执行远程部署
```bash
# 完整远程部署
./deploy/scripts/remote-deploy.sh --host 192.168.1.100 --all --env prod

# 远程健康检查
./deploy/scripts/remote-troubleshoot.sh diagnose --host 192.168.1.100
```

## 📊 监控访问

### Grafana 仪表板
```bash
# 启动端口转发
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 访问地址: http://localhost:3000
# 用户名: admin
# 密码: admin123
```

### Prometheus 指标
```bash
# 启动端口转发
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# 访问地址: http://localhost:9090
```

## 🔄 环境管理

### 创建新环境
```bash
# 创建测试环境
./deploy/scripts/env-manager.sh create --env staging

# 部署到测试环境
./deploy/scripts/k3s-deploy.sh --env staging
```

### 环境切换
```bash
# 查看所有环境
./deploy/scripts/env-manager.sh list

# 切换到生产环境
export KUBECONFIG=~/.kube/config
kubectl config set-context --current --namespace=final-ddd-prod
```

## 🚨 紧急操作

### 快速回滚
```bash
# 回滚到上一版本
./deploy/scripts/rollback.sh --env prod

# 查看回滚状态
kubectl rollout status deployment/final-ddd-app -n final-ddd-prod
```

### 紧急重启
```bash
# 重启应用
kubectl rollout restart deployment/final-ddd-app -n final-ddd-prod

# 重启数据库
kubectl rollout restart deployment/postgres -n final-ddd-prod
```

### 清理资源
```bash
# 清理开发环境
./deploy/scripts/env-manager.sh destroy --env dev --force

# 清理系统资源
./deploy/scripts/remote-troubleshoot.sh cleanup --host localhost
```

## 📚 更多信息

- [完整部署指南](deploy/README.md)
- [脚本文档](deploy/scripts/README.md)
- [监控配置](deploy/monitoring/README.md)
- [故障排除指南](docs/troubleshooting.md)

## 🆘 获取帮助

```bash
# 查看脚本帮助
./deploy/scripts/k3s-deploy.sh --help
./deploy/scripts/remote-deploy.sh --help
./deploy/scripts/env-manager.sh --help

# 运行健康检查
./deploy/scripts/health-check.sh --env dev --detailed

# 收集诊断信息
./deploy/scripts/remote-troubleshoot.sh diagnose --host localhost
```

---

**提示**: 如果遇到问题，请先运行健康检查和诊断脚本，大多数常见问题都可以自动检测和修复。
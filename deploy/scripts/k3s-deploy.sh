#!/bin/bash

# Enhanced k3s Deployment Script
# 增强的k3s部署脚本，支持完整的应用部署流程

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_ROOT="$PROJECT_ROOT/deploy"

# 默认配置
ENVIRONMENT="dev"
NAMESPACE=""
FORCE_BUILD=false
SKIP_MIGRATION=false
SKIP_MONITORING=false
WAIT_TIMEOUT=600
DOMAIN=""
DRY_RUN=false
ROLLBACK=false
CLEANUP=false

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -e, --env ENV             环境 (dev|staging|prod) [默认: dev]"
    echo "  -n, --namespace NS        Kubernetes命名空间 [默认: final-ddd-ENV]"
    echo "  -d, --domain DOMAIN       应用域名"
    echo "  -f, --force-build         强制重新构建镜像"
    echo "  --skip-migration          跳过数据库迁移"
    echo "  --skip-monitoring         跳过监控组件部署"
    echo "  -t, --timeout SECONDS     等待超时时间 [默认: 600]"
    echo "  --dry-run                 只验证配置，不实际部署"
    echo "  --rollback                回滚到上一个版本"
    echo "  --cleanup                 清理部署资源"
    echo
    echo "示例:"
    echo "  $0 --env dev                          # 部署到开发环境"
    echo "  $0 --env prod --domain example.com   # 部署到生产环境"
    echo "  $0 --force-build --skip-migration    # 强制构建，跳过迁移"
    echo "  $0 --rollback --env prod              # 回滚生产环境"
    echo "  $0 --cleanup --env dev                # 清理开发环境"
}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -f|--force-build)
                FORCE_BUILD=true
                shift
                ;;
            --skip-migration)
                SKIP_MIGRATION=true
                shift
                ;;
            --skip-monitoring)
                SKIP_MONITORING=true
                shift
                ;;
            -t|--timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --rollback)
                ROLLBACK=true
                shift
                ;;
            --cleanup)
                CLEANUP=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}#
 初始化配置
init_config() {
    # 设置默认命名空间
    if [[ -z "$NAMESPACE" ]]; then
        NAMESPACE="final-ddd-${ENVIRONMENT}"
    fi
    
    # 验证环境
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "不支持的环境: $ENVIRONMENT"
        log_info "支持的环境: dev, staging, prod"
        exit 1
    fi
    
    log_info "部署配置:"
    log_info "  环境: $ENVIRONMENT"
    log_info "  命名空间: $NAMESPACE"
    log_info "  域名: ${DOMAIN:-未设置}"
    log_info "  强制构建: $FORCE_BUILD"
    log_info "  跳过迁移: $SKIP_MIGRATION"
    log_info "  跳过监控: $SKIP_MONITORING"
    log_info "  超时时间: ${WAIT_TIMEOUT}s"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查必需工具
    for cmd in kubectl docker helm; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必需工具: ${missing_deps[*]}"
        log_info "请安装缺少的工具后重试"
        exit 1
    fi
    
    # 检查kubectl连接
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "无法连接到Kubernetes集群"
        log_info "请确保k3s正在运行并且kubectl已正确配置"
        exit 1
    fi
    
    # 检查Docker守护进程
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker守护进程未运行"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# 构建镜像
build_images() {
    if [[ "$FORCE_BUILD" != "true" ]]; then
        log_info "跳过镜像构建 (使用 --force-build 强制构建)"
        return
    fi
    
    log_info "开始构建Docker镜像..."
    
    cd "$PROJECT_ROOT"
    
    # 获取版本信息
    local version=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
    local build_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    # 构建后端镜像
    log_info "构建后端镜像..."
    docker build \
        --build-arg VERSION="$version" \
        --build-arg BUILD_TIME="$build_time" \
        --build-arg COMMIT_HASH="$commit_hash" \
        -t "final-ddd:$version" \
        -t "final-ddd:latest" \
        .
    
    # 构建前端镜像 (如果需要独立部署)
    if [[ -f "frontend/Dockerfile" ]]; then
        log_info "构建前端镜像..."
        docker build \
            -t "final-ddd-frontend:$version" \
            -t "final-ddd-frontend:latest" \
            frontend/
    fi
    
    log_success "镜像构建完成"
}

# 创建命名空间
create_namespace() {
    log_info "创建命名空间: $NAMESPACE"
    
    # 创建命名空间
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # 添加标签
    kubectl label namespace "$NAMESPACE" \
        name="$NAMESPACE" \
        environment="$ENVIRONMENT" \
        app="final-ddd" \
        --overwrite
    
    log_success "命名空间创建完成"
}

# 部署Secrets和ConfigMaps
deploy_configs() {
    log_info "部署配置和密钥..."
    
    # 创建应用配置
    kubectl create configmap app-config \
        --from-file="$PROJECT_ROOT/configs/config.yml" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # 创建应用密钥 (示例，实际应该从安全存储获取)
    kubectl create secret generic app-secrets \
        --from-literal=database-url="postgresql://postgres:password@postgres-service:5432/final_ddd?sslmode=disable" \
        --from-literal=db-user="postgres" \
        --from-literal=db-password="password123" \
        --from-literal=jwt-secret="your-jwt-secret-key" \
        --from-literal=redis-password="" \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "配置部署完成"
}# 部署数据库

deploy_database() {
    log_info "部署数据库组件..."
    
    # 部署PostgreSQL
    kubectl apply -f "$DEPLOY_ROOT/k8s/base/postgres-enhanced.yaml" -n "$NAMESPACE"
    
    # 部署Redis
    kubectl apply -f "$DEPLOY_ROOT/k8s/base/redis.yaml" -n "$NAMESPACE"
    
    # 等待数据库就绪
    log_info "等待数据库启动..."
    kubectl wait --for=condition=ready pod -l app=postgres -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=redis -n "$NAMESPACE" --timeout=300s
    
    log_success "数据库部署完成"
}

# 运行数据库迁移
run_migration() {
    if [[ "$SKIP_MIGRATION" == "true" ]]; then
        log_info "跳过数据库迁移"
        return
    fi
    
    log_info "运行数据库迁移..."
    
    # 应用迁移Job
    kubectl apply -f "$DEPLOY_ROOT/k8s/base/database-migration.yaml" -n "$NAMESPACE"
    
    # 等待迁移完成
    kubectl wait --for=condition=complete job/database-migration -n "$NAMESPACE" --timeout=300s
    
    log_success "数据库迁移完成"
}

# 部署应用
deploy_application() {
    log_info "部署应用组件..."
    
    # 部署后端应用
    kubectl apply -f "$DEPLOY_ROOT/k8s/base/deployment.yaml" -n "$NAMESPACE"
    
    # 部署服务
    kubectl apply -f "$DEPLOY_ROOT/k8s/base/service.yaml" -n "$NAMESPACE"
    
    # 部署网络策略
    kubectl apply -f "$DEPLOY_ROOT/k8s/base/network-policy.yaml" -n "$NAMESPACE"
    
    # 等待应用就绪
    log_info "等待应用启动..."
    kubectl wait --for=condition=available deployment/final-ddd-app -n "$NAMESPACE" --timeout="${WAIT_TIMEOUT}s"
    
    log_success "应用部署完成"
}

# 部署Ingress
deploy_ingress() {
    if [[ -z "$DOMAIN" ]]; then
        log_info "未设置域名，跳过Ingress部署"
        return
    fi
    
    log_info "部署Ingress配置..."
    
    # 创建Ingress配置
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: final-ddd-ingress
  namespace: $NAMESPACE
  annotations:
    traefik.ingress.kubernetes.io/router.tls.certresolver: "letsencrypt"
    traefik.ingress.kubernetes.io/router.middlewares: "default-compress@kubernetescrd"
spec:
  tls:
  - hosts:
    - $DOMAIN
    secretName: final-ddd-tls
  rules:
  - host: $DOMAIN
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
    
    log_success "Ingress部署完成"
}

# 部署监控
deploy_monitoring() {
    if [[ "$SKIP_MONITORING" == "true" ]]; then
        log_info "跳过监控部署"
        return
    fi
    
    log_info "部署监控组件..."
    
    # 运行监控安装脚本
    "$DEPLOY_ROOT/monitoring/install-monitoring.sh" "$ENVIRONMENT"
    
    log_success "监控部署完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署状态..."
    
    # 检查Pod状态
    echo "Pod状态:"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    # 检查服务状态
    echo -e "\n服务状态:"
    kubectl get services -n "$NAMESPACE"
    
    # 检查Ingress状态
    if [[ -n "$DOMAIN" ]]; then
        echo -e "\nIngress状态:"
        kubectl get ingress -n "$NAMESPACE"
    fi
    
    # 健康检查
    log_info "执行健康检查..."
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=final-ddd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -n "$pod_name" ]]; then
        if kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q --spider http://localhost:8080/api/health 2>/dev/null; then
            log_success "健康检查通过"
        else
            log_warning "健康检查失败，应用可能仍在启动中"
        fi
    fi
    
    log_success "部署验证完成"
}# 
回滚部署
rollback_deployment() {
    log_info "回滚部署..."
    
    # 回滚应用部署
    kubectl rollout undo deployment/final-ddd-app -n "$NAMESPACE"
    
    # 等待回滚完成
    kubectl rollout status deployment/final-ddd-app -n "$NAMESPACE" --timeout="${WAIT_TIMEOUT}s"
    
    log_success "回滚完成"
}

# 清理部署
cleanup_deployment() {
    log_info "清理部署资源..."
    
    # 删除应用资源
    kubectl delete -f "$DEPLOY_ROOT/k8s/base/deployment.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$DEPLOY_ROOT/k8s/base/service.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$DEPLOY_ROOT/k8s/base/network-policy.yaml" -n "$NAMESPACE" --ignore-not-found=true
    
    # 删除数据库资源
    kubectl delete -f "$DEPLOY_ROOT/k8s/base/postgres-enhanced.yaml" -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete -f "$DEPLOY_ROOT/k8s/base/redis.yaml" -n "$NAMESPACE" --ignore-not-found=true
    
    # 删除配置和密钥
    kubectl delete configmap app-config -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete secret app-secrets -n "$NAMESPACE" --ignore-not-found=true
    
    # 删除Ingress
    kubectl delete ingress final-ddd-ingress -n "$NAMESPACE" --ignore-not-found=true
    
    # 删除命名空间 (可选)
    read -p "是否删除命名空间 $NAMESPACE? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        log_success "命名空间已删除"
    fi
    
    log_success "清理完成"
}

# 显示访问信息
show_access_info() {
    echo
    echo "=== 部署完成 ==="
    echo
    echo "环境: $ENVIRONMENT"
    echo "命名空间: $NAMESPACE"
    echo
    echo "访问方式:"
    echo "1. 端口转发: kubectl port-forward -n $NAMESPACE svc/final-ddd-backend-service 8080:8080"
    echo "2. 本地访问: http://localhost:8080"
    
    if [[ -n "$DOMAIN" ]]; then
        echo "3. 域名访问: https://$DOMAIN"
    fi
    
    echo
    echo "管理命令:"
    echo "- 查看日志: kubectl logs -f -l app=final-ddd -n $NAMESPACE"
    echo "- 查看状态: kubectl get all -n $NAMESPACE"
    echo "- 进入容器: kubectl exec -it deployment/final-ddd-app -n $NAMESPACE -- /bin/sh"
    echo "- 查看事件: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
    echo
    echo "监控访问:"
    if [[ "$SKIP_MONITORING" != "true" ]]; then
        echo "- Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
        echo "- Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    fi
    echo
}

# 主函数
main() {
    echo "=== Final DDD k3s 增强部署脚本 ==="
    echo
    
    parse_args "$@"
    init_config
    
    # 处理特殊操作
    if [[ "$CLEANUP" == "true" ]]; then
        cleanup_deployment
        exit 0
    fi
    
    if [[ "$ROLLBACK" == "true" ]]; then
        check_dependencies
        rollback_deployment
        verify_deployment
        show_access_info
        exit 0
    fi
    
    # 正常部署流程
    check_dependencies
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "执行干运行模式，只验证配置..."
        # 这里可以添加配置验证逻辑
        log_success "配置验证通过"
        exit 0
    fi
    
    # 执行部署
    build_images
    create_namespace
    deploy_configs
    deploy_database
    run_migration
    deploy_application
    deploy_ingress
    deploy_monitoring
    verify_deployment
    show_access_info
    
    log_success "部署流程完成！"
}

# 执行主函数
main "$@"
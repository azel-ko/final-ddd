#!/bin/bash

# 环境管理脚本
# 用于创建、管理和销毁不同环境的部署

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 默认配置
ACTION=""
ENVIRONMENT=""
NAMESPACE=""
FORCE=false

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

# 显示帮助信息
show_help() {
    echo "用法: $0 <action> [选项]"
    echo
    echo "操作:"
    echo "  create                    创建新环境"
    echo "  destroy                   销毁环境"
    echo "  list                      列出所有环境"
    echo "  status                    显示环境状态"
    echo "  reset                     重置环境"
    echo "  backup                    备份环境数据"
    echo "  restore                   恢复环境数据"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -e, --env ENV             环境名称 (dev|staging|prod|custom)"
    echo "  -n, --namespace NS        Kubernetes命名空间"
    echo "  -f, --force               强制执行操作"
    echo
    echo "示例:"
    echo "  $0 create --env dev                   # 创建开发环境"
    echo "  $0 destroy --env staging --force      # 强制销毁测试环境"
    echo "  $0 status --env prod                  # 查看生产环境状态"
    echo "  $0 list                               # 列出所有环境"
}

# 解析命令行参数
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    ACTION="$1"
    shift
    
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
            -f|--force)
                FORCE=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 验证配置
validate_config() {
    case "$ACTION" in
        create|destroy|status|reset|backup|restore)
            if [[ -z "$ENVIRONMENT" ]]; then
                log_error "必须指定环境名称 (--env)"
                exit 1
            fi
            ;;
        list)
            # list操作不需要指定环境
            ;;
        *)
            log_error "未知操作: $ACTION"
            show_help
            exit 1
            ;;
    esac
    
    # 设置默认命名空间
    if [[ -z "$NAMESPACE" && -n "$ENVIRONMENT" ]]; then
        NAMESPACE="final-ddd-${ENVIRONMENT}"
    fi
    
    log_info "环境管理配置:"
    log_info "  操作: $ACTION"
    log_info "  环境: ${ENVIRONMENT:-N/A}"
    log_info "  命名空间: ${NAMESPACE:-N/A}"
    log_info "  强制模式: $FORCE"
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    for cmd in kubectl helm; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必需工具: ${missing_deps[*]}"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "无法连接到Kubernetes集群"
        exit 1
    fi
}

# 创建环境
create_environment() {
    log_info "创建环境: $ENVIRONMENT"
    
    # 检查环境是否已存在
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        if [[ "$FORCE" != "true" ]]; then
            log_error "环境已存在: $NAMESPACE"
            log_info "使用 --force 强制重新创建"
            exit 1
        else
            log_warning "环境已存在，将重新创建"
            destroy_environment
        fi
    fi
    
    # 创建命名空间
    log_info "创建命名空间: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
    
    # 添加标签
    kubectl label namespace "$NAMESPACE" \
        name="$NAMESPACE" \
        environment="$ENVIRONMENT" \
        app="final-ddd" \
        created-by="env-manager" \
        created-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # 创建基础配置
    create_base_configs
    
    # 根据环境类型创建特定配置
    case "$ENVIRONMENT" in
        dev)
            create_dev_environment
            ;;
        staging)
            create_staging_environment
            ;;
        prod)
            create_prod_environment
            ;;
        *)
            create_custom_environment
            ;;
    esac
    
    log_success "环境创建完成: $ENVIRONMENT"
}

# 创建基础配置
create_base_configs() {
    log_info "创建基础配置..."
    
    # 创建应用配置
    kubectl create configmap app-config \
        --from-file="$PROJECT_ROOT/configs/config.yml" \
        --namespace="$NAMESPACE"
    
    # 创建基础密钥
    kubectl create secret generic app-secrets \
        --from-literal=database-url="postgresql://postgres:password@postgres-service:5432/final_ddd?sslmode=disable" \
        --from-literal=db-user="postgres" \
        --from-literal=db-password="$(openssl rand -base64 32)" \
        --from-literal=jwt-secret="$(openssl rand -base64 64)" \
        --from-literal=redis-password="$(openssl rand -base64 32)" \
        --namespace="$NAMESPACE"
    
    log_success "基础配置创建完成"
}

# 创建开发环境
create_dev_environment() {
    log_info "配置开发环境特定设置..."
    
    # 开发环境使用较少的资源
    kubectl patch configmap app-config -n "$NAMESPACE" --patch '
    data:
      dev-config.yml: |
        app:
          debug: true
          log_level: debug
        database:
          pool:
            max_open: 10
            max_idle: 2
        redis:
          max_connections: 50
    '
    
    # 开发环境标签
    kubectl label namespace "$NAMESPACE" tier="development"
}

# 创建测试环境
create_staging_environment() {
    log_info "配置测试环境特定设置..."
    
    # 测试环境使用中等资源
    kubectl patch configmap app-config -n "$NAMESPACE" --patch '
    data:
      staging-config.yml: |
        app:
          debug: false
          log_level: info
        database:
          pool:
            max_open: 20
            max_idle: 5
        redis:
          max_connections: 100
    '
    
    kubectl label namespace "$NAMESPACE" tier="staging"
}

# 创建生产环境
create_prod_environment() {
    log_info "配置生产环境特定设置..."
    
    # 生产环境使用完整资源
    kubectl patch configmap app-config -n "$NAMESPACE" --patch '
    data:
      prod-config.yml: |
        app:
          debug: false
          log_level: warn
        database:
          pool:
            max_open: 50
            max_idle: 10
        redis:
          max_connections: 200
    '
    
    kubectl label namespace "$NAMESPACE" tier="production"
    
    # 生产环境额外安全设置
    create_network_policies
}

# 创建自定义环境
create_custom_environment() {
    log_info "配置自定义环境: $ENVIRONMENT"
    
    kubectl label namespace "$NAMESPACE" tier="custom"
}

# 创建网络策略
create_network_policies() {
    log_info "创建网络安全策略..."
    
    # 应用网络策略
    kubectl apply -f "$PROJECT_ROOT/deploy/k8s/base/network-policy.yaml" -n "$NAMESPACE"
    
    log_success "网络策略创建完成"
}# 销毁环境

destroy_environment() {
    log_info "销毁环境: $ENVIRONMENT"
    
    # 检查环境是否存在
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_warning "环境不存在: $NAMESPACE"
        return 0
    fi
    
    # 确认销毁操作
    if [[ "$FORCE" != "true" ]]; then
        echo
        log_warning "即将销毁环境: $NAMESPACE"
        log_warning "这将删除所有数据和配置！"
        read -p "确认继续? (输入 'yes' 确认): " -r
        if [[ "$REPLY" != "yes" ]]; then
            log_info "操作已取消"
            return 0
        fi
    fi
    
    # 备份数据 (如果需要)
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        log_info "生产环境，执行数据备份..."
        backup_environment_data
    fi
    
    # 删除应用资源
    log_info "删除应用资源..."
    kubectl delete all --all -n "$NAMESPACE" --timeout=300s || log_warning "删除应用资源时出现错误"
    
    # 删除PVC (持久化数据)
    log_info "删除持久化存储..."
    kubectl delete pvc --all -n "$NAMESPACE" --timeout=300s || log_warning "删除PVC时出现错误"
    
    # 删除配置和密钥
    log_info "删除配置和密钥..."
    kubectl delete configmaps --all -n "$NAMESPACE" || log_warning "删除ConfigMap时出现错误"
    kubectl delete secrets --all -n "$NAMESPACE" || log_warning "删除Secret时出现错误"
    
    # 删除命名空间
    log_info "删除命名空间..."
    kubectl delete namespace "$NAMESPACE" --timeout=300s
    
    log_success "环境销毁完成: $ENVIRONMENT"
}

# 列出所有环境
list_environments() {
    log_info "列出所有Final DDD环境..."
    
    echo
    echo "=== Final DDD 环境列表 ==="
    echo
    
    # 获取所有相关命名空间
    local namespaces=$(kubectl get namespaces -l app=final-ddd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [[ -z "$namespaces" ]]; then
        log_info "没有找到Final DDD环境"
        return 0
    fi
    
    printf "%-20s %-15s %-10s %-20s %-15s\n" "命名空间" "环境" "层级" "创建时间" "状态"
    printf "%-20s %-15s %-10s %-20s %-15s\n" "--------------------" "---------------" "----------" "--------------------" "---------------"
    
    for ns in $namespaces; do
        local env=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.environment}' 2>/dev/null || echo "unknown")
        local tier=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.tier}' 2>/dev/null || echo "unknown")
        local created=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.created-at}' 2>/dev/null || echo "unknown")
        local status=$(kubectl get namespace "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
        
        printf "%-20s %-15s %-10s %-20s %-15s\n" "$ns" "$env" "$tier" "$created" "$status"
    done
    
    echo
}

# 显示环境状态
show_environment_status() {
    log_info "显示环境状态: $ENVIRONMENT"
    
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "环境不存在: $NAMESPACE"
        exit 1
    fi
    
    echo
    echo "=== 环境状态: $ENVIRONMENT ==="
    echo
    
    # 命名空间信息
    echo "命名空间信息:"
    kubectl get namespace "$NAMESPACE" -o wide
    echo
    
    # Pod状态
    echo "Pod状态:"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo
    
    # 服务状态
    echo "服务状态:"
    kubectl get services -n "$NAMESPACE"
    echo
    
    # PVC状态
    echo "存储状态:"
    kubectl get pvc -n "$NAMESPACE" 2>/dev/null || echo "无持久化存储"
    echo
    
    # 配置和密钥
    echo "配置资源:"
    kubectl get configmaps,secrets -n "$NAMESPACE"
    echo
    
    # 资源使用情况
    echo "资源使用情况:"
    kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "无法获取资源使用信息 (需要metrics-server)"
    echo
}

# 重置环境
reset_environment() {
    log_info "重置环境: $ENVIRONMENT"
    
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "环境不存在: $NAMESPACE"
        exit 1
    fi
    
    # 确认重置操作
    if [[ "$FORCE" != "true" ]]; then
        echo
        log_warning "即将重置环境: $NAMESPACE"
        log_warning "这将重启所有服务并重置配置！"
        read -p "确认继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            return 0
        fi
    fi
    
    # 重启所有部署
    log_info "重启所有部署..."
    local deployments=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    for deployment in $deployments; do
        kubectl rollout restart deployment/"$deployment" -n "$NAMESPACE"
    done
    
    # 等待重启完成
    log_info "等待重启完成..."
    for deployment in $deployments; do
        kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout=300s
    done
    
    log_success "环境重置完成: $ENVIRONMENT"
}

# 备份环境数据
backup_environment_data() {
    log_info "备份环境数据: $ENVIRONMENT"
    
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "环境不存在: $NAMESPACE"
        exit 1
    fi
    
    local backup_dir="/tmp/final-ddd-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份配置
    log_info "备份配置资源..."
    kubectl get configmaps,secrets -n "$NAMESPACE" -o yaml > "$backup_dir/configs.yaml"
    
    # 备份数据库 (如果存在)
    local postgres_pods=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[*].metadata.name}')
    if [[ -n "$postgres_pods" ]]; then
        log_info "备份数据库..."
        for pod in $postgres_pods; do
            kubectl exec -n "$NAMESPACE" "$pod" -- pg_dumpall -U postgres > "$backup_dir/database-$pod.sql"
        done
    fi
    
    # 创建备份压缩包
    tar -czf "$backup_dir.tar.gz" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    log_success "备份完成: $backup_dir.tar.gz"
}

# 恢复环境数据
restore_environment_data() {
    log_info "恢复环境数据: $ENVIRONMENT"
    
    # 这里应该实现数据恢复逻辑
    log_warning "数据恢复功能待实现"
}

# 主函数
main() {
    echo "=== Final DDD 环境管理器 ==="
    echo
    
    parse_args "$@"
    validate_config
    
    # 对于list操作，不需要检查依赖
    if [[ "$ACTION" != "list" ]]; then
        check_dependencies
    fi
    
    # 执行相应操作
    case "$ACTION" in
        create)
            create_environment
            ;;
        destroy)
            destroy_environment
            ;;
        list)
            list_environments
            ;;
        status)
            show_environment_status
            ;;
        reset)
            reset_environment
            ;;
        backup)
            backup_environment_data
            ;;
        restore)
            restore_environment_data
            ;;
        *)
            log_error "未知操作: $ACTION"
            exit 1
            ;;
    esac
    
    log_success "操作完成: $ACTION"
}

# 执行主函数
main "$@"
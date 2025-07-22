#!/bin/bash

# k3s 应用回滚脚本
# 用于快速回滚应用到上一个版本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
ENVIRONMENT="dev"
NAMESPACE=""
REVISION=""
WAIT_TIMEOUT=300

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
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -e, --env ENV             环境 (dev|staging|prod) [默认: dev]"
    echo "  -n, --namespace NS        Kubernetes命名空间"
    echo "  -r, --revision REV        回滚到指定版本号"
    echo "  -t, --timeout SECONDS     等待超时时间 [默认: 300]"
    echo
    echo "示例:"
    echo "  $0 --env prod                    # 回滚生产环境到上一版本"
    echo "  $0 --env dev --revision 3        # 回滚到指定版本"
    echo "  $0 --namespace my-app            # 回滚指定命名空间"
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
            -r|--revision)
                REVISION="$2"
                shift 2
                ;;
            -t|--timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 初始化配置
init_config() {
    # 设置默认命名空间
    if [[ -z "$NAMESPACE" ]]; then
        NAMESPACE="final-ddd-${ENVIRONMENT}"
    fi
    
    log_info "回滚配置:"
    log_info "  环境: $ENVIRONMENT"
    log_info "  命名空间: $NAMESPACE"
    log_info "  目标版本: ${REVISION:-上一版本}"
    log_info "  超时时间: ${WAIT_TIMEOUT}s"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl 未安装"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "无法连接到Kubernetes集群"
        exit 1
    fi
    
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "命名空间 $NAMESPACE 不存在"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# 显示部署历史
show_deployment_history() {
    log_info "显示部署历史..."
    
    echo "=== 部署历史 ==="
    kubectl rollout history deployment/final-ddd-app -n "$NAMESPACE"
    echo
}

# 执行回滚
perform_rollback() {
    log_info "开始回滚部署..."
    
    # 构建回滚命令
    local rollback_cmd="kubectl rollout undo deployment/final-ddd-app -n $NAMESPACE"
    
    if [[ -n "$REVISION" ]]; then
        rollback_cmd="$rollback_cmd --to-revision=$REVISION"
        log_info "回滚到版本: $REVISION"
    else
        log_info "回滚到上一版本"
    fi
    
    # 执行回滚
    eval "$rollback_cmd"
    
    # 等待回滚完成
    log_info "等待回滚完成..."
    kubectl rollout status deployment/final-ddd-app -n "$NAMESPACE" --timeout="${WAIT_TIMEOUT}s"
    
    log_success "回滚完成"
}

# 验证回滚
verify_rollback() {
    log_info "验证回滚状态..."
    
    # 检查Pod状态
    echo "Pod状态:"
    kubectl get pods -n "$NAMESPACE" -l app=final-ddd
    
    # 检查部署状态
    echo -e "\n部署状态:"
    kubectl get deployment final-ddd-app -n "$NAMESPACE"
    
    # 健康检查
    log_info "执行健康检查..."
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=final-ddd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -n "$pod_name" ]]; then
        # 等待Pod就绪
        kubectl wait --for=condition=ready pod/"$pod_name" -n "$NAMESPACE" --timeout=60s
        
        # 执行健康检查
        if kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q --spider http://localhost:8080/api/health 2>/dev/null; then
            log_success "健康检查通过"
        else
            log_warning "健康检查失败"
            return 1
        fi
    else
        log_error "未找到应用Pod"
        return 1
    fi
    
    log_success "回滚验证完成"
}

# 显示回滚后信息
show_rollback_info() {
    echo
    echo "=== 回滚完成 ==="
    echo
    echo "环境: $ENVIRONMENT"
    echo "命名空间: $NAMESPACE"
    echo
    echo "当前部署信息:"
    kubectl get deployment final-ddd-app -n "$NAMESPACE" -o wide
    echo
    echo "访问方式:"
    echo "1. 端口转发: kubectl port-forward -n $NAMESPACE svc/final-ddd-backend-service 8080:8080"
    echo "2. 本地访问: http://localhost:8080"
    echo
    echo "管理命令:"
    echo "- 查看日志: kubectl logs -f -l app=final-ddd -n $NAMESPACE"
    echo "- 查看状态: kubectl get all -n $NAMESPACE"
    echo "- 查看历史: kubectl rollout history deployment/final-ddd-app -n $NAMESPACE"
    echo
}

# 主函数
main() {
    echo "=== k3s 应用回滚脚本 ==="
    echo
    
    parse_args "$@"
    init_config
    check_dependencies
    show_deployment_history
    
    # 确认回滚
    if [[ -z "$REVISION" ]]; then
        read -p "确认回滚到上一版本? (y/N): " -n 1 -r
    else
        read -p "确认回滚到版本 $REVISION? (y/N): " -n 1 -r
    fi
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "回滚已取消"
        exit 0
    fi
    
    # 执行回滚
    perform_rollback
    
    # 验证回滚
    if verify_rollback; then
        show_rollback_info
        log_success "回滚成功完成！"
    else
        log_error "回滚验证失败，请检查应用状态"
        exit 1
    fi
}

# 执行主函数
main "$@"
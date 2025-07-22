#!/bin/bash

# k3s 应用健康检查脚本
# 用于检查应用和基础设施的健康状态

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
DETAILED=false
CONTINUOUS=false
INTERVAL=30

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
    echo "  -d, --detailed            显示详细信息"
    echo "  -c, --continuous          持续监控模式"
    echo "  -i, --interval SECONDS    持续监控间隔 [默认: 30]"
    echo
    echo "示例:"
    echo "  $0 --env prod                    # 检查生产环境"
    echo "  $0 --detailed                   # 显示详细信息"
    echo "  $0 --continuous --interval 60   # 持续监控，60秒间隔"
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
            -d|--detailed)
                DETAILED=true
                shift
                ;;
            -c|--continuous)
                CONTINUOUS=true
                shift
                ;;
            -i|--interval)
                INTERVAL="$2"
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
    if [[ -z "$NAMESPACE" ]]; then
        NAMESPACE="final-ddd-${ENVIRONMENT}"
    fi
    
    log_info "健康检查配置:"
    log_info "  环境: $ENVIRONMENT"
    log_info "  命名空间: $NAMESPACE"
    log_info "  详细模式: $DETAILED"
    log_info "  持续监控: $CONTINUOUS"
    if [[ "$CONTINUOUS" == "true" ]]; then
        log_info "  检查间隔: ${INTERVAL}s"
    fi
}

# 检查集群连接
check_cluster_connection() {
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "无法连接到Kubernetes集群"
        return 1
    fi
    
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "命名空间 $NAMESPACE 不存在"
        return 1
    fi
    
    return 0
}

# 检查Pod状态
check_pods() {
    local status=0
    
    echo "=== Pod 状态检查 ==="
    
    # 获取所有Pod
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$pods" ]]; then
        log_warning "命名空间 $NAMESPACE 中没有找到Pod"
        return 1
    fi
    
    # 检查每个Pod
    for pod in $pods; do
        local pod_status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        local ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        
        if [[ "$pod_status" == "Running" && "$ready" == "True" ]]; then
            log_success "Pod $pod: 运行正常"
        else
            log_error "Pod $pod: 状态异常 ($pod_status, Ready: $ready)"
            status=1
            
            if [[ "$DETAILED" == "true" ]]; then
                echo "Pod详细信息:"
                kubectl describe pod "$pod" -n "$NAMESPACE" | tail -10
                echo
            fi
        fi
    done
    
    return $status
}

# 检查服务状态
check_services() {
    echo "=== 服务状态检查 ==="
    
    local services=$(kubectl get services -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$services" ]]; then
        log_warning "命名空间 $NAMESPACE 中没有找到服务"
        return 1
    fi
    
    for service in $services; do
        local endpoints=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        
        if [[ -n "$endpoints" ]]; then
            log_success "服务 $service: 端点正常 ($(echo $endpoints | wc -w) 个端点)"
        else
            log_error "服务 $service: 没有可用端点"
        fi
    done
    
    return 0
}

# 检查应用健康
check_application_health() {
    echo "=== 应用健康检查 ==="
    
    local app_pods=$(kubectl get pods -n "$NAMESPACE" -l app=final-ddd -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$app_pods" ]]; then
        log_error "没有找到应用Pod"
        return 1
    fi
    
    local healthy_count=0
    local total_count=0
    
    for pod in $app_pods; do
        ((total_count++))
        
        # 检查健康端点
        if kubectl exec -n "$NAMESPACE" "$pod" -- wget -q --spider http://localhost:8080/api/health 2>/dev/null; then
            log_success "Pod $pod: 健康检查通过"
            ((healthy_count++))
        else
            log_error "Pod $pod: 健康检查失败"
        fi
    done
    
    echo "健康状态: $healthy_count/$total_count Pod正常"
    
    if [[ $healthy_count -eq $total_count ]]; then
        return 0
    else
        return 1
    fi
}

# 检查数据库连接
check_database() {
    echo "=== 数据库连接检查 ==="
    
    # 检查PostgreSQL
    local postgres_pods=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -n "$postgres_pods" ]]; then
        for pod in $postgres_pods; do
            if kubectl exec -n "$NAMESPACE" "$pod" -- pg_isready -U postgres 2>/dev/null; then
                log_success "PostgreSQL $pod: 连接正常"
            else
                log_error "PostgreSQL $pod: 连接失败"
            fi
        done
    else
        log_warning "没有找到PostgreSQL Pod"
    fi
    
    # 检查Redis
    local redis_pods=$(kubectl get pods -n "$NAMESPACE" -l app=redis -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -n "$redis_pods" ]]; then
        for pod in $redis_pods; do
            if kubectl exec -n "$NAMESPACE" "$pod" -- redis-cli ping 2>/dev/null | grep -q PONG; then
                log_success "Redis $pod: 连接正常"
            else
                log_error "Redis $pod: 连接失败"
            fi
        done
    else
        log_warning "没有找到Redis Pod"
    fi
    
    return 0
}

# 检查资源使用情况
check_resource_usage() {
    if [[ "$DETAILED" != "true" ]]; then
        return 0
    fi
    
    echo "=== 资源使用情况 ==="
    
    # 检查节点资源
    echo "节点资源使用:"
    kubectl top nodes 2>/dev/null || log_warning "无法获取节点资源信息 (需要metrics-server)"
    
    echo
    echo "Pod资源使用:"
    kubectl top pods -n "$NAMESPACE" 2>/dev/null || log_warning "无法获取Pod资源信息 (需要metrics-server)"
    
    return 0
}

# 检查事件
check_events() {
    if [[ "$DETAILED" != "true" ]]; then
        return 0
    fi
    
    echo "=== 最近事件 ==="
    
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
    
    return 0
}

# 执行完整健康检查
perform_health_check() {
    local overall_status=0
    
    echo "$(date): 开始健康检查..."
    echo
    
    # 检查集群连接
    if ! check_cluster_connection; then
        return 1
    fi
    
    # 检查各个组件
    check_pods || overall_status=1
    echo
    
    check_services || overall_status=1
    echo
    
    check_application_health || overall_status=1
    echo
    
    check_database || overall_status=1
    echo
    
    check_resource_usage
    echo
    
    check_events
    echo
    
    # 显示总体状态
    if [[ $overall_status -eq 0 ]]; then
        log_success "整体健康状态: 正常"
    else
        log_error "整体健康状态: 异常"
    fi
    
    return $overall_status
}

# 主函数
main() {
    parse_args "$@"
    init_config
    
    if [[ "$CONTINUOUS" == "true" ]]; then
        log_info "开始持续监控模式 (按 Ctrl+C 停止)..."
        
        while true; do
            clear
            echo "=== Final DDD 健康监控 ==="
            echo "环境: $ENVIRONMENT | 命名空间: $NAMESPACE | 间隔: ${INTERVAL}s"
            echo "时间: $(date)"
            echo
            
            perform_health_check
            
            echo
            echo "下次检查: $(date -d "+${INTERVAL} seconds")"
            sleep "$INTERVAL"
        done
    else
        echo "=== Final DDD 健康检查 ==="
        echo "环境: $ENVIRONMENT | 命名空间: $NAMESPACE"
        echo
        
        if perform_health_check; then
            exit 0
        else
            exit 1
        fi
    fi
}

# 执行主函数
main "$@"
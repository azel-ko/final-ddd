#!/bin/bash

# 监控配置更新脚本
# 用于更新监控组件的配置而无需重新部署整个监控栈

set -e

# 默认配置
NAMESPACE=${1:-monitoring}
CONFIG_TYPE=${2:-all}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 显示使用说明
show_usage() {
    echo "使用方法: $0 [命名空间] [配置类型]"
    echo ""
    echo "参数:"
    echo "  命名空间  : Kubernetes命名空间 (默认: monitoring)"
    echo "  配置类型  : 要更新的配置类型 (默认: all)"
    echo ""
    echo "支持的配置类型:"
    echo "  all           - 更新所有配置"
    echo "  prometheus    - 更新Prometheus配置"
    echo "  grafana       - 更新Grafana配置"
    echo "  rules         - 更新告警规则"
    echo "  secrets       - 更新密钥配置"
    echo ""
    echo "示例:"
    echo "  $0                    # 更新monitoring命名空间的所有配置"
    echo "  $0 monitoring prometheus  # 只更新Prometheus配置"
    echo "  $0 prod-monitoring rules  # 更新生产环境的告警规则"
}

# 检查依赖
check_dependencies() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在PATH中"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群"
        exit 1
    fi
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "命名空间 $NAMESPACE 不存在"
        exit 1
    fi
}

# 更新Prometheus配置
update_prometheus_config() {
    log_info "更新Prometheus配置..."
    
    if [[ -f "$SCRIPT_DIR/configs/prometheus-config.yaml" ]]; then
        kubectl apply -f "$SCRIPT_DIR/configs/prometheus-config.yaml" -n "$NAMESPACE"
        
        # 重启Prometheus以加载新配置
        kubectl rollout restart deployment/prometheus-server -n "$NAMESPACE" 2>/dev/null || \
        kubectl rollout restart statefulset/prometheus-prometheus-kube-prometheus-prometheus -n "$NAMESPACE" 2>/dev/null || \
        log_warning "无法自动重启Prometheus，请手动重启"
        
        log_success "Prometheus配置更新完成"
    else
        log_error "Prometheus配置文件不存在"
        return 1
    fi
}

# 更新Grafana配置
update_grafana_config() {
    log_info "更新Grafana配置..."
    
    # 更新数据源配置
    if [[ -f "$SCRIPT_DIR/configs/grafana-datasources.yaml" ]]; then
        kubectl apply -f "$SCRIPT_DIR/configs/grafana-datasources.yaml" -n "$NAMESPACE"
    fi
    
    # 更新服务发现配置
    if [[ -f "$SCRIPT_DIR/configs/service-discovery.yaml" ]]; then
        kubectl apply -f "$SCRIPT_DIR/configs/service-discovery.yaml" -n "$NAMESPACE"
    fi
    
    # 重启Grafana以加载新配置
    kubectl rollout restart deployment/grafana -n "$NAMESPACE" 2>/dev/null || \
    log_warning "无法自动重启Grafana，请手动重启"
    
    log_success "Grafana配置更新完成"
}

# 更新告警规则
update_prometheus_rules() {
    log_info "更新Prometheus告警规则..."
    
    if [[ -f "$SCRIPT_DIR/configs/prometheus-rules.yaml" ]]; then
        kubectl apply -f "$SCRIPT_DIR/configs/prometheus-rules.yaml" -n "$NAMESPACE"
        
        # 触发Prometheus重新加载规则
        local prometheus_pod=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=prometheus" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$prometheus_pod" ]]; then
            kubectl exec -n "$NAMESPACE" "$prometheus_pod" -- kill -HUP 1 2>/dev/null || \
            log_warning "无法发送HUP信号给Prometheus，规则将在下次重启时生效"
        fi
        
        log_success "告警规则更新完成"
    else
        log_error "告警规则文件不存在"
        return 1
    fi
}

# 更新密钥配置
update_secrets() {
    log_info "更新监控密钥配置..."
    
    if [[ -f "$SCRIPT_DIR/secrets/monitoring-secrets.yaml" ]]; then
        kubectl apply -f "$SCRIPT_DIR/secrets/monitoring-secrets.yaml" -n "$NAMESPACE"
        
        log_warning "密钥更新后，相关Pod需要重启才能生效"
        log_info "如需立即生效，请运行以下命令："
        echo "  kubectl rollout restart deployment/grafana -n $NAMESPACE"
        echo "  kubectl rollout restart deployment/prometheus-server -n $NAMESPACE"
        
        log_success "密钥配置更新完成"
    else
        log_warning "密钥配置文件不存在，跳过更新"
    fi
}

# 验证配置更新
verify_config_update() {
    log_info "验证配置更新..."
    
    # 检查ConfigMaps
    local configmaps=(
        "prometheus-config"
        "grafana-datasources"
        "prometheus-service-discovery"
        "prometheus-rules"
    )
    
    for cm in "${configmaps[@]}"; do
        if kubectl get configmap "$cm" -n "$NAMESPACE" &> /dev/null; then
            log_success "ConfigMap $cm 存在"
        else
            log_warning "ConfigMap $cm 不存在"
        fi
    done
    
    # 检查Secrets
    if kubectl get secret "monitoring-secrets" -n "$NAMESPACE" &> /dev/null; then
        log_success "Secret monitoring-secrets 存在"
    else
        log_warning "Secret monitoring-secrets 不存在"
    fi
    
    # 检查Pod状态
    log_info "检查Pod状态..."
    kubectl get pods -n "$NAMESPACE" -o wide
}

# 显示重启命令
show_restart_commands() {
    echo ""
    echo "=== 手动重启命令 ==="
    echo "如果配置未自动生效，请使用以下命令手动重启相关组件："
    echo ""
    echo "重启Prometheus:"
    echo "  kubectl rollout restart deployment/prometheus-server -n $NAMESPACE"
    echo "  # 或者"
    echo "  kubectl rollout restart statefulset/prometheus-prometheus-kube-prometheus-prometheus -n $NAMESPACE"
    echo ""
    echo "重启Grafana:"
    echo "  kubectl rollout restart deployment/grafana -n $NAMESPACE"
    echo ""
    echo "重启AlertManager:"
    echo "  kubectl rollout restart deployment/alertmanager -n $NAMESPACE"
    echo ""
    echo "查看重启状态:"
    echo "  kubectl rollout status deployment/grafana -n $NAMESPACE"
    echo ""
}

# 主函数
main() {
    # 显示标题
    echo "=================================="
    echo "    监控配置更新脚本"
    echo "=================================="
    echo ""
    
    # 检查参数
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    log_info "开始更新监控配置..."
    log_info "命名空间: $NAMESPACE"
    log_info "配置类型: $CONFIG_TYPE"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 根据配置类型执行相应的更新
    case "$CONFIG_TYPE" in
        "all")
            update_prometheus_config
            update_grafana_config
            update_prometheus_rules
            update_secrets
            ;;
        "prometheus")
            update_prometheus_config
            ;;
        "grafana")
            update_grafana_config
            ;;
        "rules")
            update_prometheus_rules
            ;;
        "secrets")
            update_secrets
            ;;
        *)
            log_error "不支持的配置类型: $CONFIG_TYPE"
            show_usage
            exit 1
            ;;
    esac
    
    # 验证更新
    verify_config_update
    
    # 显示重启命令
    show_restart_commands
    
    log_success "监控配置更新完成！"
}

# 执行主函数
main "$@"
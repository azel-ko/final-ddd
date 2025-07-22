#!/bin/bash

# 监控组件安装脚本
# 支持不同环境的监控栈部署

set -e

# 默认配置
ENVIRONMENT=${1:-dev}
NAMESPACE=${2:-monitoring}
HELM_RELEASE_NAME=${3:-monitoring-stack}
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
    echo "使用方法: $0 [环境] [命名空间] [Helm发布名称]"
    echo ""
    echo "参数:"
    echo "  环境        : dev, staging, prod (默认: dev)"
    echo "  命名空间    : Kubernetes命名空间 (默认: monitoring)"
    echo "  Helm发布名称: Helm发布的名称 (默认: monitoring-stack)"
    echo ""
    echo "示例:"
    echo "  $0 dev"
    echo "  $0 prod monitoring prod-monitoring"
    echo ""
    echo "支持的环境:"
    echo "  dev     - 开发环境 (资源较少，短期数据保留)"
    echo "  staging - 测试环境 (中等资源，中期数据保留)"
    echo "  prod    - 生产环境 (高资源，长期数据保留)"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖工具..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在PATH中"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm 未安装或不在PATH中"
        exit 1
    fi
    
    # 检查kubectl连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# 创建命名空间
create_namespace() {
    log_info "创建命名空间: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "命名空间 $NAMESPACE 已存在"
    else
        kubectl create namespace "$NAMESPACE"
        log_success "命名空间 $NAMESPACE 创建成功"
    fi
    
    # 添加标签
    kubectl label namespace "$NAMESPACE" name="$NAMESPACE" --overwrite
}

# 安装或更新ConfigMaps
install_configmaps() {
    log_info "安装ConfigMaps..."
    
    # Prometheus配置
    kubectl apply -f "$SCRIPT_DIR/configs/prometheus-config.yaml" -n "$NAMESPACE"
    
    # Grafana数据源配置
    kubectl apply -f "$SCRIPT_DIR/configs/grafana-datasources.yaml" -n "$NAMESPACE"
    
    # 服务发现配置
    kubectl apply -f "$SCRIPT_DIR/configs/service-discovery.yaml" -n "$NAMESPACE"
    
    # Prometheus规则
    kubectl apply -f "$SCRIPT_DIR/configs/prometheus-rules.yaml" -n "$NAMESPACE"
    
    log_success "ConfigMaps安装完成"
}

# 安装或更新Secrets
install_secrets() {
    log_info "安装Secrets..."
    
    # 检查secrets文件是否存在
    if [[ -f "$SCRIPT_DIR/secrets/monitoring-secrets.yaml" ]]; then
        kubectl apply -f "$SCRIPT_DIR/secrets/monitoring-secrets.yaml" -n "$NAMESPACE"
        log_success "Secrets安装完成"
    else
        log_warning "Secrets文件不存在，跳过安装"
        log_info "请手动创建监控相关的secrets"
    fi
}

# 添加Helm仓库
add_helm_repos() {
    log_info "添加Helm仓库..."
    
    # Prometheus社区仓库
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    
    # Grafana仓库
    helm repo add grafana https://grafana.github.io/helm-charts
    
    # 更新仓库
    helm repo update
    
    log_success "Helm仓库添加完成"
}

# 安装监控栈
install_monitoring_stack() {
    log_info "安装监控栈 (环境: $ENVIRONMENT)..."
    
    # 确定values文件
    local base_values="$SCRIPT_DIR/values/base-values.yaml"
    local env_values="$SCRIPT_DIR/values/${ENVIRONMENT}-values.yaml"
    
    # 检查values文件是否存在
    if [[ ! -f "$base_values" ]]; then
        log_error "基础values文件不存在: $base_values"
        exit 1
    fi
    
    # 构建helm命令参数
    local helm_args=()
    helm_args+=("--namespace" "$NAMESPACE")
    helm_args+=("--create-namespace")
    helm_args+=("--values" "$base_values")
    
    # 如果环境特定的values文件存在，则添加
    if [[ -f "$env_values" ]]; then
        helm_args+=("--values" "$env_values")
        log_info "使用环境特定配置: $env_values"
    else
        log_warning "环境特定配置文件不存在: $env_values，使用基础配置"
    fi
    
    # 设置环境变量
    helm_args+=("--set" "global.environment=$ENVIRONMENT")
    
    # 检查是否已安装
    if helm list -n "$NAMESPACE" | grep -q "$HELM_RELEASE_NAME"; then
        log_info "更新现有的监控栈..."
        helm upgrade "$HELM_RELEASE_NAME" prometheus-community/kube-prometheus-stack "${helm_args[@]}"
    else
        log_info "安装新的监控栈..."
        helm install "$HELM_RELEASE_NAME" prometheus-community/kube-prometheus-stack "${helm_args[@]}"
    fi
    
    log_success "监控栈安装/更新完成"
}

# 等待部署完成
wait_for_deployment() {
    log_info "等待监控组件启动..."
    
    # 等待Prometheus
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-server -n "$NAMESPACE" || true
    
    # 等待Grafana
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n "$NAMESPACE" || true
    
    # 检查Pod状态
    log_info "检查Pod状态..."
    kubectl get pods -n "$NAMESPACE"
    
    log_success "监控组件启动完成"
}

# 显示访问信息
show_access_info() {
    log_info "获取访问信息..."
    
    echo ""
    echo "=== 监控组件访问信息 ==="
    
    # Grafana访问信息
    local grafana_service=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "grafana")
    if kubectl get svc "$grafana_service" -n "$NAMESPACE" &> /dev/null; then
        echo "Grafana:"
        echo "  服务: $grafana_service"
        echo "  端口转发: kubectl port-forward -n $NAMESPACE svc/$grafana_service 3000:80"
        echo "  访问地址: http://localhost:3000"
        echo "  默认用户: admin"
        echo "  默认密码: admin123 (请及时修改)"
    fi
    
    # Prometheus访问信息
    local prometheus_service=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=prometheus" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "prometheus-server")
    if kubectl get svc "$prometheus_service" -n "$NAMESPACE" &> /dev/null; then
        echo ""
        echo "Prometheus:"
        echo "  服务: $prometheus_service"
        echo "  端口转发: kubectl port-forward -n $NAMESPACE svc/$prometheus_service 9090:80"
        echo "  访问地址: http://localhost:9090"
    fi
    
    # AlertManager访问信息
    local alertmanager_service=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=alertmanager" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "alertmanager")
    if kubectl get svc "$alertmanager_service" -n "$NAMESPACE" &> /dev/null; then
        echo ""
        echo "AlertManager:"
        echo "  服务: $alertmanager_service"
        echo "  端口转发: kubectl port-forward -n $NAMESPACE svc/$alertmanager_service 9093:9093"
        echo "  访问地址: http://localhost:9093"
    fi
    
    echo ""
    echo "=== 有用的命令 ==="
    echo "查看所有监控组件: kubectl get all -n $NAMESPACE"
    echo "查看Pod日志: kubectl logs -n $NAMESPACE <pod-name>"
    echo "删除监控栈: helm uninstall $HELM_RELEASE_NAME -n $NAMESPACE"
    echo ""
}

# 主函数
main() {
    # 显示标题
    echo "=================================="
    echo "    监控组件安装脚本"
    echo "=================================="
    echo ""
    
    # 检查参数
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # 验证环境参数
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "不支持的环境: $ENVIRONMENT"
        log_info "支持的环境: dev, staging, prod"
        exit 1
    fi
    
    log_info "开始安装监控栈..."
    log_info "环境: $ENVIRONMENT"
    log_info "命名空间: $NAMESPACE"
    log_info "Helm发布名称: $HELM_RELEASE_NAME"
    echo ""
    
    # 执行安装步骤
    check_dependencies
    create_namespace
    install_configmaps
    install_secrets
    add_helm_repos
    install_monitoring_stack
    wait_for_deployment
    show_access_info
    
    log_success "监控栈安装完成！"
}

# 执行主函数
main "$@"
#!/bin/bash

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
DEPLOY_ROOT="$PROJECT_ROOT/deploy"

# 默认值
ENVIRONMENT="dev"
FORCE_BUILD=false
WAIT_TIMEOUT=300
DOMAIN=""

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -e, --env ENV             设置环境 (dev|staging|prod) [默认: dev]"
    echo "  -d, --domain DOMAIN       设置应用域名"
    echo "  -f, --force-build         强制重新构建镜像"
    echo "  -t, --timeout SECONDS     等待部署完成的超时时间 [默认: 300]"
    echo
    echo "示例:"
    echo "  $0 --env dev                           # 部署到开发环境"
    echo "  $0 --env prod --domain example.com    # 部署到生产环境"
    echo "  $0 --force-build                      # 强制构建并部署"
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
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -f|--force-build)
                FORCE_BUILD=true
                shift
                ;;
            -t|--timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}# 检
查环境
check_environment() {
    echo -e "${BLUE}检查部署环境...${NC}"
    
    # 检查 kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        echo -e "${RED}错误: kubectl 未安装${NC}"
        exit 1
    fi
    
    # 检查集群连接
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}错误: 无法连接到 Kubernetes 集群${NC}"
        echo "请确保 k3s 正在运行并且 kubectl 已正确配置"
        exit 1
    fi
    
    # 检查环境配置
    if [[ ! -d "$DEPLOY_ROOT/k8s/environments/$ENVIRONMENT" ]]; then
        echo -e "${RED}错误: 环境配置不存在: $ENVIRONMENT${NC}"
        echo "可用环境: dev, staging, prod"
        exit 1
    fi
    
    echo -e "${GREEN}环境检查通过${NC}"
}

# 构建镜像
build_images() {
    if [[ "$FORCE_BUILD" == "true" ]]; then
        echo -e "${BLUE}强制重新构建镜像...${NC}"
        cd "$PROJECT_ROOT"
        ./scripts/build.sh --target docker --push
    else
        echo -e "${YELLOW}跳过镜像构建 (使用 --force-build 强制构建)${NC}"
    fi
}

# 验证配置
validate_manifests() {
    echo -e "${BLUE}验证 Kubernetes 配置...${NC}"
    
    if ! kubectl apply --dry-run=client -k "$DEPLOY_ROOT/k8s/environments/$ENVIRONMENT" >/dev/null 2>&1; then
        echo -e "${RED}错误: Kubernetes 配置验证失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}配置验证通过${NC}"
}

# 部署应用
deploy_application() {
    echo -e "${BLUE}部署应用到 $ENVIRONMENT 环境...${NC}"
    
    # 应用配置
    kubectl apply -k "$DEPLOY_ROOT/k8s/environments/$ENVIRONMENT"
    
    # 等待部署完成
    echo "等待部署完成..."
    local deployment_name="${ENVIRONMENT}-final-ddd-app"
    local namespace="final-ddd-${ENVIRONMENT}"
    
    if kubectl rollout status deployment/"$deployment_name" -n "$namespace" --timeout="${WAIT_TIMEOUT}s"; then
        echo -e "${GREEN}应用部署成功${NC}"
    else
        echo -e "${RED}应用部署失败或超时${NC}"
        echo "查看详细信息:"
        echo "  kubectl describe deployment/$deployment_name -n $namespace"
        echo "  kubectl logs -l app=final-ddd -n $namespace"
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    echo -e "${BLUE}验证部署状态...${NC}"
    
    local namespace="final-ddd-${ENVIRONMENT}"
    
    # 检查 Pod 状态
    echo "Pod 状态:"
    kubectl get pods -n "$namespace" -l app=final-ddd
    
    # 检查服务状态
    echo -e "\n服务状态:"
    kubectl get services -n "$namespace"
    
    # 检查 Ingress 状态
    echo -e "\nIngress 状态:"
    kubectl get ingress -n "$namespace" 2>/dev/null || echo "未配置 Ingress"
    
    # 健康检查
    echo -e "\n执行健康检查..."
    local pod_name=$(kubectl get pods -n "$namespace" -l app=final-ddd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -n "$pod_name" ]]; then
        if kubectl exec -n "$namespace" "$pod_name" -- wget -q --spider http://localhost:8080/health 2>/dev/null; then
            echo -e "${GREEN}健康检查通过${NC}"
        else
            echo -e "${YELLOW}健康检查失败，应用可能仍在启动中${NC}"
        fi
    fi
}

# 显示访问信息
show_access_info() {
    echo -e "${GREEN}=== 部署完成 ===${NC}"
    echo
    echo "环境: $ENVIRONMENT"
    echo "命名空间: final-ddd-${ENVIRONMENT}"
    echo
    echo "访问方式:"
    echo "1. 端口转发: kubectl port-forward svc/${ENVIRONMENT}-final-ddd-service 8080:8080 -n final-ddd-${ENVIRONMENT}"
    echo "2. 本地访问: http://localhost:8080"
    
    if [[ -n "$DOMAIN" ]]; then
        echo "3. 域名访问: https://$DOMAIN"
    fi
    
    echo
    echo "管理命令:"
    echo "- 查看日志: kubectl logs -f -l app=final-ddd -n final-ddd-${ENVIRONMENT}"
    echo "- 查看状态: kubectl get all -n final-ddd-${ENVIRONMENT}"
    echo "- 进入容器: kubectl exec -it deployment/${ENVIRONMENT}-final-ddd-app -n final-ddd-${ENVIRONMENT} -- /bin/sh"
}

# 主函数
main() {
    echo -e "${GREEN}=== Final DDD k3s 部署脚本 ===${NC}"
    
    parse_args "$@"
    check_environment
    validate_manifests
    build_images
    deploy_application
    verify_deployment
    show_access_info
}

# 执行主函数
main "$@"
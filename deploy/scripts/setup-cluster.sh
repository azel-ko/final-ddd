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

# 默认配置
ENVIRONMENT="dev"
INSTALL_MONITORING=true
INSTALL_CERT_MANAGER=true
REPLACE_TRAEFIK=false

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -e, --env ENV             环境 (dev|staging|prod) [默认: dev]"
    echo "  --skip-monitoring         跳过监控组件安装"
    echo "  --skip-cert-manager       跳过证书管理器安装"
    echo "  --replace-traefik         替换内置 Traefik 为 Nginx Ingress"
    echo
    echo "示例:"
    echo "  $0                        # 设置开发环境"
    echo "  $0 --env prod             # 设置生产环境"
    echo "  $0 --replace-traefik      # 使用 Nginx 替换 Traefik"
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
            --skip-monitoring)
                INSTALL_MONITORING=false
                shift
                ;;
            --skip-cert-manager)
                INSTALL_CERT_MANAGER=false
                shift
                ;;
            --replace-traefik)
                REPLACE_TRAEFIK=true
                shift
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查 k3s 是否运行
check_k3s() {
    echo -e "${BLUE}检查 k3s 状态...${NC}"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        echo -e "${RED}错误: kubectl 未安装或未配置${NC}"
        echo "请先运行: ./deploy/scripts/install-k3s.sh"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}错误: 无法连接到 k3s 集群${NC}"
        echo "请检查 k3s 是否正常运行"
        exit 1
    fi
    
    echo -e "${GREEN}k3s 集群运行正常${NC}"
}

# 安装 Helm
install_helm() {
    echo -e "${BLUE}检查 Helm 安装...${NC}"
    
    if command -v helm >/dev/null 2>&1; then
        echo "Helm 已安装: $(helm version --short)"
        return
    fi
    
    echo "安装 Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    echo -e "${GREEN}Helm 安装完成${NC}"
}

# 添加 Helm 仓库
add_helm_repos() {
    echo -e "${BLUE}添加 Helm 仓库...${NC}"
    
    # 添加常用仓库
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add jetstack https://charts.jetstack.io
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    
    # 更新仓库
    helm repo update
    
    echo -e "${GREEN}Helm 仓库添加完成${NC}"
}

# 安装证书管理器
install_cert_manager() {
    if [[ "$INSTALL_CERT_MANAGER" != "true" ]]; then
        echo -e "${YELLOW}跳过证书管理器安装${NC}"
        return
    fi
    
    echo -e "${BLUE}安装 cert-manager...${NC}"
    
    # 检查是否已安装
    if kubectl get namespace cert-manager >/dev/null 2>&1; then
        echo "cert-manager 已安装"
        return
    fi
    
    # 安装 CRDs
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.crds.yaml
    
    # 创建命名空间
    kubectl create namespace cert-manager
    
    # 安装 cert-manager
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --version v1.13.2
    
    # 等待部署完成
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
    
    echo -e "${GREEN}cert-manager 安装完成${NC}"
}

# 替换 Traefik 为 Nginx Ingress
replace_traefik_with_nginx() {
    if [[ "$REPLACE_TRAEFIK" != "true" ]]; then
        echo -e "${YELLOW}保持使用内置 Traefik${NC}"
        return
    fi
    
    echo -e "${BLUE}替换 Traefik 为 Nginx Ingress...${NC}"
    
    # 禁用 Traefik
    echo "禁用内置 Traefik..."
    kubectl patch configmap traefik-config -n kube-system --type merge -p '{"data":{"traefik.yaml":""}}'
    kubectl delete deployment traefik -n kube-system --ignore-not-found=true
    
    # 安装 Nginx Ingress
    echo "安装 Nginx Ingress Controller..."
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer
    
    # 等待部署完成
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s
    
    echo -e "${GREEN}Nginx Ingress 安装完成${NC}"
}

# 安装监控组件
install_monitoring() {
    if [[ "$INSTALL_MONITORING" != "true" ]]; then
        echo -e "${YELLOW}跳过监控组件安装${NC}"
        return
    fi
    
    echo -e "${BLUE}安装监控组件...${NC}"
    
    # 创建监控命名空间
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # 安装 Prometheus
    echo "安装 Prometheus..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.retention=15d \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
        --set grafana.persistence.enabled=true \
        --set grafana.persistence.size=1Gi \
        --set grafana.adminPassword=admin123
    
    # 等待部署完成
    echo "等待监控组件启动..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
    
    echo -e "${GREEN}监控组件安装完成${NC}"
    echo -e "${YELLOW}Grafana 默认密码: admin123${NC}"
}

# 创建 ClusterIssuer
create_cluster_issuer() {
    if [[ "$INSTALL_CERT_MANAGER" != "true" ]]; then
        return
    fi
    
    echo -e "${BLUE}创建 Let's Encrypt ClusterIssuer...${NC}"
    
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
    
    echo -e "${GREEN}ClusterIssuer 创建完成${NC}"
}

# 显示集群状态
show_cluster_status() {
    echo -e "${BLUE}集群状态总览...${NC}"
    
    echo -e "\n${YELLOW}节点状态:${NC}"
    kubectl get nodes
    
    echo -e "\n${YELLOW}命名空间:${NC}"
    kubectl get namespaces
    
    echo -e "\n${YELLOW}系统 Pods:${NC}"
    kubectl get pods -n kube-system
    
    if [[ "$INSTALL_MONITORING" == "true" ]]; then
        echo -e "\n${YELLOW}监控 Pods:${NC}"
        kubectl get pods -n monitoring
    fi
    
    if [[ "$INSTALL_CERT_MANAGER" == "true" ]]; then
        echo -e "\n${YELLOW}证书管理 Pods:${NC}"
        kubectl get pods -n cert-manager
    fi
    
    echo -e "\n${YELLOW}服务状态:${NC}"
    kubectl get services --all-namespaces
}

# 创建快速访问脚本
create_access_scripts() {
    echo -e "${BLUE}创建快速访问脚本...${NC}"
    
    # 创建 Grafana 访问脚本
    if [[ "$INSTALL_MONITORING" == "true" ]]; then
        cat > "$PROJECT_ROOT/access-grafana.sh" <<'EOF'
#!/bin/bash
echo "正在启动 Grafana 端口转发..."
echo "访问地址: http://localhost:3000"
echo "用户名: admin"
echo "密码: admin123"
echo "按 Ctrl+C 停止"
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
EOF
        chmod +x "$PROJECT_ROOT/access-grafana.sh"
    fi
    
    # 创建 Prometheus 访问脚本
    if [[ "$INSTALL_MONITORING" == "true" ]]; then
        cat > "$PROJECT_ROOT/access-prometheus.sh" <<'EOF'
#!/bin/bash
echo "正在启动 Prometheus 端口转发..."
echo "访问地址: http://localhost:9090"
echo "按 Ctrl+C 停止"
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
EOF
        chmod +x "$PROJECT_ROOT/access-prometheus.sh"
    fi
    
    echo -e "${GREEN}访问脚本创建完成${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}=== k3s 集群设置脚本 ===${NC}"
    
    parse_args "$@"
    check_k3s
    install_helm
    add_helm_repos
    install_cert_manager
    replace_traefik_with_nginx
    install_monitoring
    create_cluster_issuer
    create_access_scripts
    show_cluster_status
    
    echo -e "${GREEN}=== k3s 集群设置完成 ===${NC}"
    echo
    echo "集群已准备就绪！"
    echo
    echo "快速访问:"
    if [[ "$INSTALL_MONITORING" == "true" ]]; then
        echo "- Grafana: ./access-grafana.sh"
        echo "- Prometheus: ./access-prometheus.sh"
    fi
    echo
    echo "下一步:"
    echo "1. 部署应用: make deploy ENV=$ENVIRONMENT"
    echo "2. 查看状态: kubectl get all -n final-ddd-$ENVIRONMENT"
}

# 执行主函数
main "$@"
#!/bin/bash

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
K3S_VERSION="v1.28.5+k3s1"
INSTALL_MODE="single"  # single, server, agent
SERVER_IP=""
TOKEN=""
DISABLE_TRAEFIK=false
ENABLE_METRICS=true

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -v, --version VERSION     k3s 版本 [默认: $K3S_VERSION]"
    echo "  -m, --mode MODE           安装模式 (single|server|agent) [默认: single]"
    echo "  -s, --server-ip IP        服务器 IP (agent 模式需要)"
    echo "  -t, --token TOKEN         集群 token (agent 模式需要)"
    echo "  --disable-traefik         禁用内置 Traefik"
    echo "  --disable-metrics         禁用指标收集"
    echo
    echo "安装模式说明:"
    echo "  single  - 单节点模式，包含所有组件"
    echo "  server  - 服务器节点，可以添加 agent 节点"
    echo "  agent   - 工作节点，需要连接到 server"
    echo
    echo "示例:"
    echo "  $0                                    # 单节点安装"
    echo "  $0 --mode server                     # 安装服务器节点"
    echo "  $0 --mode agent --server-ip 1.2.3.4 --token xxx  # 安装工作节点"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                K3S_VERSION="$2"
                shift 2
                ;;
            -m|--mode)
                INSTALL_MODE="$2"
                shift 2
                ;;
            -s|--server-ip)
                SERVER_IP="$2"
                shift 2
                ;;
            -t|--token)
                TOKEN="$2"
                shift 2
                ;;
            --disable-traefik)
                DISABLE_TRAEFIK=true
                shift
                ;;
            --disable-metrics)
                ENABLE_METRICS=false
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

# 检查系统要求
check_requirements() {
    echo -e "${BLUE}检查系统要求...${NC}"
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${RED}错误: 无法检测操作系统${NC}"
        exit 1
    fi
    
    # 检查是否为 root 用户
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}警告: 建议使用非 root 用户运行此脚本${NC}"
    fi
    
    # 检查内存
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -lt 1 ]]; then
        echo -e "${YELLOW}警告: 系统内存少于 1GB，可能影响性能${NC}"
    fi
    
    # 检查磁盘空间
    local disk_gb=$(df / | awk 'NR==2{print int($4/1024/1024)}')
    if [[ $disk_gb -lt 5 ]]; then
        echo -e "${YELLOW}警告: 根分区可用空间少于 5GB${NC}"
    fi
    
    echo -e "${GREEN}系统要求检查完成${NC}"
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}安装系统依赖...${NC}"
    
    # 检测包管理器
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y curl wget
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y curl wget
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y curl wget
    else
        echo -e "${YELLOW}警告: 无法检测包管理器，请手动安装 curl 和 wget${NC}"
    fi
}

# 安装 k3s
install_k3s() {
    echo -e "${BLUE}安装 k3s ${K3S_VERSION}...${NC}"
    
    # 构建安装参数
    local install_args=""
    
    case $INSTALL_MODE in
        single)
            echo "安装单节点 k3s..."
            ;;
        server)
            echo "安装 k3s 服务器节点..."
            install_args="--cluster-init"
            ;;
        agent)
            if [[ -z "$SERVER_IP" || -z "$TOKEN" ]]; then
                echo -e "${RED}错误: agent 模式需要指定 --server-ip 和 --token${NC}"
                exit 1
            fi
            echo "安装 k3s 工作节点，连接到 $SERVER_IP..."
            install_args="--server https://$SERVER_IP:6443 --token $TOKEN"
            ;;
    esac
    
    # 添加可选参数
    if [[ "$DISABLE_TRAEFIK" == "true" ]]; then
        install_args="$install_args --disable traefik"
    fi
    
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        install_args="$install_args --enable-metrics"
    fi
    
    # 执行安装
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - $install_args
    
    # 等待 k3s 启动
    echo -e "${BLUE}等待 k3s 启动...${NC}"
    sleep 10
    
    # 检查安装状态
    if systemctl is-active --quiet k3s || systemctl is-active --quiet k3s-agent; then
        echo -e "${GREEN}k3s 安装成功！${NC}"
    else
        echo -e "${RED}k3s 安装失败${NC}"
        exit 1
    fi
}

# 配置 kubectl
setup_kubectl() {
    echo -e "${BLUE}配置 kubectl...${NC}"
    
    if [[ "$INSTALL_MODE" != "agent" ]]; then
        # 为当前用户设置 kubeconfig
        mkdir -p ~/.kube
        sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
        sudo chown $(id -u):$(id -g) ~/.kube/config
        
        # 设置环境变量
        echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
        export KUBECONFIG=~/.kube/config
        
        echo -e "${GREEN}kubectl 配置完成${NC}"
    else
        echo -e "${YELLOW}agent 节点不需要配置 kubectl${NC}"
    fi
}

# 验证安装
verify_installation() {
    echo -e "${BLUE}验证 k3s 安装...${NC}"
    
    if [[ "$INSTALL_MODE" != "agent" ]]; then
        # 检查节点状态
        echo "节点状态:"
        kubectl get nodes
        
        # 检查系统 pods
        echo -e "\n系统 Pods 状态:"
        kubectl get pods -n kube-system
        
        # 显示集群信息
        echo -e "\n集群信息:"
        kubectl cluster-info
        
        # 如果是服务器模式，显示 token
        if [[ "$INSTALL_MODE" == "server" ]]; then
            echo -e "\n${YELLOW}集群 Token (用于添加 agent 节点):${NC}"
            sudo cat /var/lib/rancher/k3s/server/node-token
        fi
    else
        echo "Agent 节点安装完成"
    fi
}

# 创建基础命名空间
create_namespaces() {
    if [[ "$INSTALL_MODE" != "agent" ]]; then
        echo -e "${BLUE}创建基础命名空间...${NC}"
        
        kubectl create namespace final-ddd-dev --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace final-ddd-staging --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace final-ddd-prod --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
        
        echo -e "${GREEN}命名空间创建完成${NC}"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}=== k3s 安装脚本 ===${NC}"
    
    parse_args "$@"
    check_requirements
    install_dependencies
    install_k3s
    setup_kubectl
    verify_installation
    create_namespaces
    
    echo -e "${GREEN}=== k3s 安装完成 ===${NC}"
    echo
    echo "下一步:"
    if [[ "$INSTALL_MODE" == "server" ]]; then
        echo "1. 记录上面显示的 Token"
        echo "2. 在其他节点上运行: $0 --mode agent --server-ip $(hostname -I | awk '{print $1}') --token <TOKEN>"
    fi
    echo "3. 使用 kubectl 管理集群: kubectl get nodes"
    echo "4. 部署应用: make deploy ENV=dev"
}

# 执行主函数
main "$@"
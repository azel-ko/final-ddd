#!/bin/bash

# 远程k3s部署脚本
# 支持SSH远程部署到多个服务器

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
REMOTE_HOST=""
REMOTE_USER="root"
SSH_KEY=""
SSH_PORT=22
ENVIRONMENT="dev"
INSTALL_K3S=false
SETUP_CLUSTER=false
DEPLOY_APP=false

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
    echo "  -H, --host HOST           远程主机地址"
    echo "  -u, --user USER           SSH用户名 [默认: root]"
    echo "  -k, --key PATH            SSH私钥路径"
    echo "  -p, --port PORT           SSH端口 [默认: 22]"
    echo "  -e, --env ENV             环境 (dev|staging|prod) [默认: dev]"
    echo "  --install-k3s             安装k3s"
    echo "  --setup-cluster           设置集群组件"
    echo "  --deploy-app              部署应用"
    echo "  --all                     执行完整部署流程"
    echo
    echo "示例:"
    echo "  $0 --host 192.168.1.100 --all                    # 完整远程部署"
    echo "  $0 --host server.com --user ubuntu --install-k3s # 安装k3s"
    echo "  $0 --host 10.0.1.10 --deploy-app --env prod      # 部署应用到生产环境"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -H|--host)
                REMOTE_HOST="$2"
                shift 2
                ;;
            -u|--user)
                REMOTE_USER="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY="$2"
                shift 2
                ;;
            -p|--port)
                SSH_PORT="$2"
                shift 2
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --install-k3s)
                INSTALL_K3S=true
                shift
                ;;
            --setup-cluster)
                SETUP_CLUSTER=true
                shift
                ;;
            --deploy-app)
                DEPLOY_APP=true
                shift
                ;;
            --all)
                INSTALL_K3S=true
                SETUP_CLUSTER=true
                DEPLOY_APP=true
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
    if [[ -z "$REMOTE_HOST" ]]; then
        log_error "必须指定远程主机地址 (--host)"
        exit 1
    fi
    
    if [[ -n "$SSH_KEY" && ! -f "$SSH_KEY" ]]; then
        log_error "SSH私钥文件不存在: $SSH_KEY"
        exit 1
    fi
    
    log_info "远程部署配置:"
    log_info "  远程主机: $REMOTE_HOST"
    log_info "  SSH用户: $REMOTE_USER"
    log_info "  SSH端口: $SSH_PORT"
    log_info "  SSH密钥: ${SSH_KEY:-使用默认}"
    log_info "  环境: $ENVIRONMENT"
    log_info "  安装k3s: $INSTALL_K3S"
    log_info "  设置集群: $SETUP_CLUSTER"
    log_info "  部署应用: $DEPLOY_APP"
}

# 构建SSH命令
build_ssh_cmd() {
    local ssh_cmd="ssh -p $SSH_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY"
    fi
    
    ssh_cmd="$ssh_cmd -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    ssh_cmd="$ssh_cmd $REMOTE_USER@$REMOTE_HOST"
    
    echo "$ssh_cmd"
}

# 测试SSH连接
test_ssh_connection() {
    log_info "测试SSH连接..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    if $ssh_cmd "echo 'SSH连接测试成功'" >/dev/null 2>&1; then
        log_success "SSH连接正常"
    else
        log_error "SSH连接失败"
        log_info "请检查:"
        log_info "  1. 主机地址是否正确"
        log_info "  2. SSH服务是否运行"
        log_info "  3. 用户名和密钥是否正确"
        log_info "  4. 防火墙设置"
        exit 1
    fi
}

# 主函数
main() {
    echo "=== Final DDD 远程部署脚本 ==="
    echo
    
    parse_args "$@"
    validate_config
    
    # 检查本地依赖
    if ! command -v ssh >/dev/null 2>&1; then
        log_error "SSH客户端未安装"
        exit 1
    fi
    
    # 执行远程部署流程
    test_ssh_connection
    
    log_info "远程部署功能正在开发中..."
    log_info "请使用本地部署脚本: ./deploy/scripts/k3s-deploy.sh"
    
    log_success "远程部署脚本执行完成！"
}

# 执行主函数
main "$@"
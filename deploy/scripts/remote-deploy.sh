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
FORCE_BUILD=true

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

# 构建SCP命令
build_scp_cmd() {
    local scp_cmd="scp -P $SSH_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        scp_cmd="$scp_cmd -i $SSH_KEY"
    fi
    
    scp_cmd="$scp_cmd -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    
    echo "$scp_cmd"
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

# 检查远程系统
check_remote_system() {
    log_info "检查远程系统..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    # 获取系统信息
    local os_info=$($ssh_cmd "cat /etc/os-release | grep PRETTY_NAME" | cut -d'"' -f2)
    local kernel_info=$($ssh_cmd "uname -r")
    local memory_info=$($ssh_cmd "free -h | grep Mem | awk '{print \$2}'")
    local disk_info=$($ssh_cmd "df -h / | tail -1 | awk '{print \$4}'")
    
    log_info "远程系统信息:"
    log_info "  操作系统: $os_info"
    log_info "  内核版本: $kernel_info"
    log_info "  内存大小: $memory_info"
    log_info "  可用磁盘: $disk_info"
    
    # 检查系统要求
    local mem_gb=$($ssh_cmd "free -g | awk '/^Mem:/{print \$2}'")
    if [[ $mem_gb -lt 2 ]]; then
        log_warning "内存少于2GB，可能影响k3s性能"
    fi
}

# 上传部署文件
upload_deployment_files() {
    log_info "上传部署文件..."
    
    local scp_cmd=$(build_scp_cmd)
    local ssh_cmd=$(build_ssh_cmd)
    
    # 创建远程目录
    $ssh_cmd "mkdir -p /tmp/final-ddd-deploy"
    
    # 上传脚本文件
    $scp_cmd "$SCRIPT_DIR"/*.sh "$REMOTE_USER@$REMOTE_HOST:/tmp/final-ddd-deploy/"
    
    # 上传k8s配置文件
    $scp_cmd -r "$PROJECT_ROOT/deploy/k8s" "$REMOTE_USER@$REMOTE_HOST:/tmp/final-ddd-deploy/"
    
    # 上传监控配置
    $scp_cmd -r "$PROJECT_ROOT/deploy/monitoring" "$REMOTE_USER@$REMOTE_HOST:/tmp/final-ddd-deploy/"
    
    # 上传应用配置
    $scp_cmd -r "$PROJECT_ROOT/configs" "$REMOTE_USER@$REMOTE_HOST:/tmp/final-ddd-deploy/"
    
    # 设置执行权限
    $ssh_cmd "chmod +x /tmp/final-ddd-deploy/*.sh"
    
    log_success "文件上传完成"
}# 远程安装
k3s
remote_install_k3s() {
    if [[ "$INSTALL_K3S" != "true" ]]; then
        return 0
    fi
    
    log_info "远程安装k3s..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    # 执行k3s安装
    $ssh_cmd "cd /tmp/final-ddd-deploy && ./install-k3s.sh --mode single"
    
    # 等待k3s启动
    log_info "等待k3s启动..."
    sleep 30
    
    # 验证安装
    if $ssh_cmd "kubectl get nodes" >/dev/null 2>&1; then
        log_success "k3s安装成功"
    else
        log_error "k3s安装失败"
        exit 1
    fi
}

# 远程设置集群
remote_setup_cluster() {
    if [[ "$SETUP_CLUSTER" != "true" ]]; then
        return 0
    fi
    
    log_info "远程设置集群组件..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    # 执行集群设置
    $ssh_cmd "cd /tmp/final-ddd-deploy && ./setup-cluster.sh --env $ENVIRONMENT"
    
    log_success "集群设置完成"
}

# 构建和推送镜像
build_and_push_images() {
    if [[ "$DEPLOY_APP" != "true" ]]; then
        return 0
    fi
    
    log_info "构建和推送Docker镜像..."
    
    cd "$PROJECT_ROOT"
    
    # 获取版本信息
    local version=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
    local build_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    # 构建镜像
    docker build \
        --build-arg VERSION="$version" \
        --build-arg BUILD_TIME="$build_time" \
        --build-arg COMMIT_HASH="$commit_hash" \
        -t "final-ddd:$version" \
        -t "final-ddd:latest" \
        .
    
    # 保存镜像为tar文件
    log_info "导出Docker镜像..."
    docker save final-ddd:latest | gzip > /tmp/final-ddd-image.tar.gz
    
    # 上传镜像到远程服务器
    log_info "上传镜像到远程服务器..."
    local scp_cmd=$(build_scp_cmd)
    $scp_cmd /tmp/final-ddd-image.tar.gz "$REMOTE_USER@$REMOTE_HOST:/tmp/"
    
    # 在远程服务器加载镜像
    log_info "在远程服务器加载镜像..."
    local ssh_cmd=$(build_ssh_cmd)
    $ssh_cmd "gunzip -c /tmp/final-ddd-image.tar.gz | docker load"
    
    # 清理临时文件
    rm -f /tmp/final-ddd-image.tar.gz
    $ssh_cmd "rm -f /tmp/final-ddd-image.tar.gz"
    
    log_success "镜像构建和推送完成"
}

# 远程部署应用
remote_deploy_application() {
    if [[ "$DEPLOY_APP" != "true" ]]; then
        return 0
    fi
    
    log_info "远程部署应用..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    # 执行应用部署
    $ssh_cmd "cd /tmp/final-ddd-deploy && ./k3s-deploy.sh --env $ENVIRONMENT --skip-monitoring"
    
    log_success "应用部署完成"
}

# 远程健康检查
remote_health_check() {
    log_info "执行远程健康检查..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    # 执行健康检查
    if $ssh_cmd "cd /tmp/final-ddd-deploy && ./health-check.sh --env $ENVIRONMENT"; then
        log_success "远程健康检查通过"
    else
        log_warning "远程健康检查失败，请检查应用状态"
    fi
}

# 显示远程访问信息
show_remote_access_info() {
    log_info "获取远程访问信息..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    echo
    echo "=== 远程部署完成 ==="
    echo
    echo "远程主机: $REMOTE_HOST"
    echo "环境: $ENVIRONMENT"
    echo
    echo "远程访问方式:"
    echo "1. SSH隧道: ssh -L 8080:localhost:8080 $REMOTE_USER@$REMOTE_HOST"
    echo "2. 然后访问: http://localhost:8080"
    echo
    echo "远程管理命令:"
    echo "- 查看状态: ssh $REMOTE_USER@$REMOTE_HOST 'kubectl get all -n final-ddd-$ENVIRONMENT'"
    echo "- 查看日志: ssh $REMOTE_USER@$REMOTE_HOST 'kubectl logs -f -l app=final-ddd -n final-ddd-$ENVIRONMENT'"
    echo "- 健康检查: ssh $REMOTE_USER@$REMOTE_HOST 'cd /tmp/final-ddd-deploy && ./health-check.sh --env $ENVIRONMENT'"
    echo
    
    # 获取节点信息
    echo "远程集群状态:"
    $ssh_cmd "kubectl get nodes -o wide" || log_warning "无法获取节点信息"
    echo
}

# 清理远程文件
cleanup_remote_files() {
    log_info "清理远程临时文件..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    $ssh_cmd "rm -rf /tmp/final-ddd-deploy" || log_warning "清理远程文件失败"
    
    log_success "远程文件清理完成"
}

# 主函数
main() {
    echo "=== Final DDD 远程部署脚本 ==="
    echo
    
    parse_args "$@"
    validate_config
    
    # 检查本地依赖
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker未安装"
        exit 1
    fi
    
    if ! command -v ssh >/dev/null 2>&1; then
        log_error "SSH客户端未安装"
        exit 1
    fi
    
    # 执行远程部署流程
    test_ssh_connection
    check_remote_system
    upload_deployment_files
    
    # 根据选项执行相应操作
    remote_install_k3s
    remote_setup_cluster
    build_and_push_images
    remote_deploy_application
    
    # 验证和清理
    remote_health_check
    show_remote_access_info
    
    # 询问是否清理临时文件
    read -p "是否清理远程临时文件? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        cleanup_remote_files
    fi
    
    log_success "远程部署流程完成！"
}

# 执行主函数
main "$@"
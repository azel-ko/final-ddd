#!/bin/bash

# 远程测试环境设置脚本
# 用于准备和验证远程服务器的部署环境

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
REMOTE_HOST=""
REMOTE_USER="root"
SSH_KEY=""
SSH_PORT=22
CHECK_ONLY=false
INSTALL_DEPS=false
SETUP_DOCKER=false
SETUP_FIREWALL=false

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
    echo "  --check-only              只检查环境，不安装"
    echo "  --install-deps            安装系统依赖"
    echo "  --setup-docker            设置Docker环境"
    echo "  --setup-firewall          配置防火墙"
    echo "  --all                     执行完整设置"
    echo
    echo "示例:"
    echo "  $0 --host 192.168.1.100 --check-only         # 只检查环境"
    echo "  $0 --host server.com --all                   # 完整设置"
    echo "  $0 --host 10.0.1.10 --install-deps          # 只安装依赖"
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
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            --install-deps)
                INSTALL_DEPS=true
                shift
                ;;
            --setup-docker)
                SETUP_DOCKER=true
                shift
                ;;
            --setup-firewall)
                SETUP_FIREWALL=true
                shift
                ;;
            --all)
                INSTALL_DEPS=true
                SETUP_DOCKER=true
                SETUP_FIREWALL=true
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
    
    log_info "远程测试环境设置配置:"
    log_info "  远程主机: $REMOTE_HOST"
    log_info "  SSH用户: $REMOTE_USER"
    log_info "  SSH端口: $SSH_PORT"
    log_info "  SSH密钥: ${SSH_KEY:-使用默认}"
    log_info "  只检查: $CHECK_ONLY"
    log_info "  安装依赖: $INSTALL_DEPS"
    log_info "  设置Docker: $SETUP_DOCKER"
    log_info "  设置防火墙: $SETUP_FIREWALL"
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
        return 0
    else
        log_error "SSH连接失败"
        log_info "请检查:"
        log_info "  1. 主机地址: $REMOTE_HOST"
        log_info "  2. SSH端口: $SSH_PORT"
        log_info "  3. 用户名: $REMOTE_USER"
        log_info "  4. SSH密钥: ${SSH_KEY:-默认}"
        log_info "  5. 防火墙设置"
        return 1
    fi
}

# 检查系统信息
check_system_info() {
    log_info "检查远程系统信息..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    echo "=== 系统信息 ==="
    
    # 操作系统信息
    local os_info=$($ssh_cmd "cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'\"' -f2" || echo "未知")
    echo "操作系统: $os_info"
    
    # 内核版本
    local kernel_info=$($ssh_cmd "uname -r")
    echo "内核版本: $kernel_info"
    
    # CPU信息
    local cpu_info=$($ssh_cmd "lscpu | grep 'Model name' | cut -d':' -f2 | xargs" || echo "未知")
    local cpu_cores=$($ssh_cmd "nproc")
    echo "CPU: $cpu_info ($cpu_cores 核心)"
    
    # 内存信息
    local memory_total=$($ssh_cmd "free -h | grep Mem | awk '{print \$2}'")
    local memory_available=$($ssh_cmd "free -h | grep Mem | awk '{print \$7}'")
    echo "内存: $memory_total (可用: $memory_available)"
    
    # 磁盘信息
    local disk_info=$($ssh_cmd "df -h / | tail -1 | awk '{print \$2 \" (可用: \" \$4 \")\"}'")
    echo "磁盘: $disk_info"
    
    # 网络信息
    local ip_info=$($ssh_cmd "hostname -I | awk '{print \$1}'")
    echo "IP地址: $ip_info"
    
    echo
}

# 检查系统要求
check_system_requirements() {
    log_info "检查系统要求..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local requirements_met=true
    
    echo "=== 系统要求检查 ==="
    
    # 检查内存 (至少2GB)
    local mem_gb=$($ssh_cmd "free -g | awk '/^Mem:/{print \$2}'")
    if [[ $mem_gb -ge 2 ]]; then
        log_success "内存: ${mem_gb}GB (满足要求)"
    else
        log_error "内存: ${mem_gb}GB (需要至少2GB)"
        requirements_met=false
    fi
    
    # 检查磁盘空间 (至少10GB)
    local disk_gb=$($ssh_cmd "df / | awk 'NR==2{print int(\$4/1024/1024)}'")
    if [[ $disk_gb -ge 10 ]]; then
        log_success "磁盘空间: ${disk_gb}GB (满足要求)"
    else
        log_error "磁盘空间: ${disk_gb}GB (需要至少10GB)"
        requirements_met=false
    fi
    
    # 检查CPU核心数 (至少1核)
    local cpu_cores=$($ssh_cmd "nproc")
    if [[ $cpu_cores -ge 1 ]]; then
        log_success "CPU核心: ${cpu_cores}核 (满足要求)"
    else
        log_error "CPU核心: ${cpu_cores}核 (需要至少1核)"
        requirements_met=false
    fi
    
    # 检查架构
    local arch=$($ssh_cmd "uname -m")
    if [[ "$arch" == "x86_64" || "$arch" == "aarch64" ]]; then
        log_success "系统架构: $arch (支持)"
    else
        log_warning "系统架构: $arch (可能不支持)"
    fi
    
    echo
    
    if [[ "$requirements_met" == "true" ]]; then
        log_success "系统要求检查通过"
        return 0
    else
        log_error "系统要求检查失败"
        return 1
    fi
}# 检查网络连
接
check_network_connectivity() {
    log_info "检查网络连接..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    echo "=== 网络连接检查 ==="
    
    # 检查DNS解析
    if $ssh_cmd "nslookup google.com >/dev/null 2>&1"; then
        log_success "DNS解析正常"
    else
        log_error "DNS解析失败"
    fi
    
    # 检查外网连接
    if $ssh_cmd "curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1"; then
        log_success "外网连接正常"
    else
        log_error "外网连接失败"
    fi
    
    # 检查Docker Hub连接
    if $ssh_cmd "curl -s --connect-timeout 5 https://hub.docker.com >/dev/null 2>&1"; then
        log_success "Docker Hub连接正常"
    else
        log_warning "Docker Hub连接失败"
    fi
    
    echo
}

# 检查已安装的软件
check_installed_software() {
    log_info "检查已安装的软件..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    echo "=== 软件安装状态 ==="
    
    # 检查Docker
    if $ssh_cmd "command -v docker >/dev/null 2>&1"; then
        local docker_version=$($ssh_cmd "docker --version | cut -d' ' -f3 | cut -d',' -f1")
        log_success "Docker: $docker_version"
    else
        log_warning "Docker: 未安装"
    fi
    
    # 检查curl
    if $ssh_cmd "command -v curl >/dev/null 2>&1"; then
        log_success "curl: 已安装"
    else
        log_warning "curl: 未安装"
    fi
    
    # 检查wget
    if $ssh_cmd "command -v wget >/dev/null 2>&1"; then
        log_success "wget: 已安装"
    else
        log_warning "wget: 未安装"
    fi
    
    # 检查git
    if $ssh_cmd "command -v git >/dev/null 2>&1"; then
        local git_version=$($ssh_cmd "git --version | cut -d' ' -f3")
        log_success "git: $git_version"
    else
        log_warning "git: 未安装"
    fi
    
    echo
}

# 安装系统依赖
install_system_dependencies() {
    if [[ "$INSTALL_DEPS" != "true" ]]; then
        return 0
    fi
    
    log_info "安装系统依赖..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    # 检测包管理器并安装依赖
    if $ssh_cmd "command -v apt-get >/dev/null 2>&1"; then
        log_info "使用apt-get安装依赖..."
        $ssh_cmd "apt-get update && apt-get install -y curl wget git unzip"
    elif $ssh_cmd "command -v yum >/dev/null 2>&1"; then
        log_info "使用yum安装依赖..."
        $ssh_cmd "yum update -y && yum install -y curl wget git unzip"
    elif $ssh_cmd "command -v dnf >/dev/null 2>&1"; then
        log_info "使用dnf安装依赖..."
        $ssh_cmd "dnf update -y && dnf install -y curl wget git unzip"
    else
        log_error "无法检测包管理器"
        return 1
    fi
    
    log_success "系统依赖安装完成"
}

# 设置Docker环境
setup_docker_environment() {
    if [[ "$SETUP_DOCKER" != "true" ]]; then
        return 0
    fi
    
    log_info "设置Docker环境..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    # 检查Docker是否已安装
    if $ssh_cmd "command -v docker >/dev/null 2>&1"; then
        log_info "Docker已安装，检查服务状态..."
        
        # 启动Docker服务
        $ssh_cmd "systemctl enable docker && systemctl start docker"
        
        # 检查Docker服务状态
        if $ssh_cmd "systemctl is-active docker >/dev/null 2>&1"; then
            log_success "Docker服务运行正常"
        else
            log_error "Docker服务启动失败"
            return 1
        fi
    else
        log_info "安装Docker..."
        
        # 安装Docker
        $ssh_cmd "curl -fsSL https://get.docker.com | sh"
        
        # 启动Docker服务
        $ssh_cmd "systemctl enable docker && systemctl start docker"
        
        # 将用户添加到docker组
        if [[ "$REMOTE_USER" != "root" ]]; then
            $ssh_cmd "usermod -aG docker $REMOTE_USER"
            log_info "用户 $REMOTE_USER 已添加到docker组，需要重新登录生效"
        fi
    fi
    
    # 测试Docker
    if $ssh_cmd "docker run --rm hello-world >/dev/null 2>&1"; then
        log_success "Docker测试通过"
    else
        log_error "Docker测试失败"
        return 1
    fi
    
    log_success "Docker环境设置完成"
}

# 配置防火墙
setup_firewall() {
    if [[ "$SETUP_FIREWALL" != "true" ]]; then
        return 0
    fi
    
    log_info "配置防火墙..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    # 检查防火墙类型
    if $ssh_cmd "command -v ufw >/dev/null 2>&1"; then
        log_info "配置UFW防火墙..."
        
        # 允许SSH
        $ssh_cmd "ufw allow $SSH_PORT/tcp"
        
        # 允许k3s端口
        $ssh_cmd "ufw allow 6443/tcp"  # k3s API
        $ssh_cmd "ufw allow 80/tcp"    # HTTP
        $ssh_cmd "ufw allow 443/tcp"   # HTTPS
        $ssh_cmd "ufw allow 8080/tcp"  # 应用端口
        
        # 启用防火墙
        $ssh_cmd "echo 'y' | ufw enable"
        
    elif $ssh_cmd "command -v firewall-cmd >/dev/null 2>&1"; then
        log_info "配置firewalld防火墙..."
        
        # 启动firewalld
        $ssh_cmd "systemctl enable firewalld && systemctl start firewalld"
        
        # 允许端口
        $ssh_cmd "firewall-cmd --permanent --add-port=$SSH_PORT/tcp"
        $ssh_cmd "firewall-cmd --permanent --add-port=6443/tcp"
        $ssh_cmd "firewall-cmd --permanent --add-port=80/tcp"
        $ssh_cmd "firewall-cmd --permanent --add-port=443/tcp"
        $ssh_cmd "firewall-cmd --permanent --add-port=8080/tcp"
        
        # 重新加载配置
        $ssh_cmd "firewall-cmd --reload"
        
    else
        log_warning "未检测到支持的防火墙，跳过配置"
    fi
    
    log_success "防火墙配置完成"
}

# 生成环境报告
generate_environment_report() {
    log_info "生成环境报告..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local report_file="/tmp/remote-env-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=== 远程环境报告 ==="
        echo "生成时间: $(date)"
        echo "远程主机: $REMOTE_HOST"
        echo "SSH用户: $REMOTE_USER"
        echo
        
        echo "=== 系统信息 ==="
        $ssh_cmd "uname -a"
        $ssh_cmd "cat /etc/os-release" 2>/dev/null || echo "无法获取OS信息"
        echo
        
        echo "=== 硬件信息 ==="
        $ssh_cmd "lscpu | head -20" 2>/dev/null || echo "无法获取CPU信息"
        $ssh_cmd "free -h"
        $ssh_cmd "df -h"
        echo
        
        echo "=== 网络信息 ==="
        $ssh_cmd "ip addr show" 2>/dev/null || $ssh_cmd "ifconfig" 2>/dev/null || echo "无法获取网络信息"
        echo
        
        echo "=== 已安装软件 ==="
        $ssh_cmd "docker --version" 2>/dev/null || echo "Docker: 未安装"
        $ssh_cmd "curl --version | head -1" 2>/dev/null || echo "curl: 未安装"
        $ssh_cmd "wget --version | head -1" 2>/dev/null || echo "wget: 未安装"
        $ssh_cmd "git --version" 2>/dev/null || echo "git: 未安装"
        echo
        
        echo "=== 服务状态 ==="
        $ssh_cmd "systemctl is-active docker" 2>/dev/null || echo "Docker服务: 未运行"
        echo
        
    } > "$report_file"
    
    log_success "环境报告已生成: $report_file"
    
    # 显示报告摘要
    echo
    echo "=== 环境报告摘要 ==="
    cat "$report_file"
}

# 主函数
main() {
    echo "=== 远程测试环境设置脚本 ==="
    echo
    
    parse_args "$@"
    validate_config
    
    # 测试SSH连接
    if ! test_ssh_connection; then
        exit 1
    fi
    
    # 检查系统信息
    check_system_info
    
    # 检查系统要求
    if ! check_system_requirements; then
        if [[ "$CHECK_ONLY" == "true" ]]; then
            log_error "系统要求检查失败，无法继续"
            exit 1
        else
            log_warning "系统要求检查失败，但将继续设置"
        fi
    fi
    
    # 检查网络连接
    check_network_connectivity
    
    # 检查已安装软件
    check_installed_software
    
    # 如果只是检查，到此结束
    if [[ "$CHECK_ONLY" == "true" ]]; then
        log_info "环境检查完成"
        generate_environment_report
        exit 0
    fi
    
    # 执行设置操作
    install_system_dependencies
    setup_docker_environment
    setup_firewall
    
    # 生成最终报告
    generate_environment_report
    
    log_success "远程测试环境设置完成！"
    echo
    echo "下一步:"
    echo "1. 运行远程部署: ./deploy/scripts/remote-deploy.sh --host $REMOTE_HOST --all"
    echo "2. 或者单独安装k3s: ./deploy/scripts/remote-deploy.sh --host $REMOTE_HOST --install-k3s"
}

# 执行主函数
main "$@"
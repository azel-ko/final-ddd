#!/bin/bash

# 远程故障排除工具脚本
# 用于远程诊断和解决部署问题

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
ENVIRONMENT="dev"
ACTION=""
LOG_LINES=100
AUTO_FIX=false

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
    echo "用法: $0 <action> [选项]"
    echo
    echo "操作:"
    echo "  diagnose                  全面诊断系统状态"
    echo "  logs                      收集应用日志"
    echo "  status                    检查服务状态"
    echo "  restart                   重启服务"
    echo "  cleanup                   清理系统资源"
    echo "  fix-common                修复常见问题"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -H, --host HOST           远程主机地址"
    echo "  -u, --user USER           SSH用户名 [默认: root]"
    echo "  -k, --key PATH            SSH私钥路径"
    echo "  -p, --port PORT           SSH端口 [默认: 22]"
    echo "  -e, --env ENV             环境 (dev|staging|prod) [默认: dev]"
    echo "  -l, --lines NUM           日志行数 [默认: 100]"
    echo "  --auto-fix                自动修复发现的问题"
    echo
    echo "示例:"
    echo "  $0 diagnose --host 192.168.1.100         # 全面诊断"
    echo "  $0 logs --host server.com --lines 200    # 收集200行日志"
    echo "  $0 restart --host 10.0.1.10 --env prod   # 重启生产环境服务"
}

# 解析命令行参数
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    ACTION="$1"
    shift
    
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
            -l|--lines)
                LOG_LINES="$2"
                shift 2
                ;;
            --auto-fix)
                AUTO_FIX=true
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
    
    case "$ACTION" in
        diagnose|logs|status|restart|cleanup|fix-common)
            ;;
        *)
            log_error "未知操作: $ACTION"
            show_help
            exit 1
            ;;
    esac
    
    log_info "远程故障排除配置:"
    log_info "  操作: $ACTION"
    log_info "  远程主机: $REMOTE_HOST"
    log_info "  SSH用户: $REMOTE_USER"
    log_info "  环境: $ENVIRONMENT"
    log_info "  自动修复: $AUTO_FIX"
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
        return 1
    fi
}

# 全面诊断系统
diagnose_system() {
    log_info "开始全面系统诊断..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local namespace="final-ddd-${ENVIRONMENT}"
    
    echo "=== 系统诊断报告 ==="
    echo "时间: $(date)"
    echo "主机: $REMOTE_HOST"
    echo "环境: $ENVIRONMENT"
    echo
    
    # 1. 系统资源检查
    echo "=== 系统资源状态 ==="
    echo "CPU使用率:"
    $ssh_cmd "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d'%' -f1" || echo "无法获取CPU信息"
    
    echo "内存使用:"
    $ssh_cmd "free -h"
    
    echo "磁盘使用:"
    $ssh_cmd "df -h"
    
    echo "负载平均:"
    $ssh_cmd "uptime"
    echo
    
    # 2. Docker状态检查
    echo "=== Docker状态 ==="
    if $ssh_cmd "command -v docker >/dev/null 2>&1"; then
        echo "Docker版本:"
        $ssh_cmd "docker --version"
        
        echo "Docker服务状态:"
        $ssh_cmd "systemctl is-active docker" || echo "Docker服务未运行"
        
        echo "Docker镜像:"
        $ssh_cmd "docker images | head -10"
        
        echo "运行中的容器:"
        $ssh_cmd "docker ps"
    else
        log_error "Docker未安装"
    fi
    echo
    
    # 3. k3s状态检查
    echo "=== k3s状态 ==="
    if $ssh_cmd "command -v kubectl >/dev/null 2>&1"; then
        echo "kubectl版本:"
        $ssh_cmd "kubectl version --client --short" 2>/dev/null || echo "无法获取kubectl版本"
        
        echo "集群状态:"
        $ssh_cmd "kubectl cluster-info" 2>/dev/null || echo "无法连接到集群"
        
        echo "节点状态:"
        $ssh_cmd "kubectl get nodes" 2>/dev/null || echo "无法获取节点信息"
        
        echo "命名空间状态:"
        $ssh_cmd "kubectl get namespaces" 2>/dev/null || echo "无法获取命名空间信息"
    else
        log_error "kubectl未安装或未配置"
    fi
    echo
    
    # 4. 应用状态检查
    echo "=== 应用状态 ($namespace) ==="
    if $ssh_cmd "kubectl get namespace $namespace >/dev/null 2>&1"; then
        echo "Pod状态:"
        $ssh_cmd "kubectl get pods -n $namespace -o wide" 2>/dev/null || echo "无法获取Pod信息"
        
        echo "服务状态:"
        $ssh_cmd "kubectl get services -n $namespace" 2>/dev/null || echo "无法获取服务信息"
        
        echo "部署状态:"
        $ssh_cmd "kubectl get deployments -n $namespace" 2>/dev/null || echo "无法获取部署信息"
        
        echo "事件:"
        $ssh_cmd "kubectl get events -n $namespace --sort-by='.lastTimestamp' | tail -10" 2>/dev/null || echo "无法获取事件信息"
    else
        log_error "命名空间 $namespace 不存在"
    fi
    echo
    
    # 5. 网络检查
    echo "=== 网络状态 ==="
    echo "网络接口:"
    $ssh_cmd "ip addr show | grep -E '^[0-9]+:|inet '" 2>/dev/null || $ssh_cmd "ifconfig" 2>/dev/null || echo "无法获取网络信息"
    
    echo "端口监听:"
    $ssh_cmd "netstat -tlnp | grep -E ':(80|443|6443|8080)'" 2>/dev/null || $ssh_cmd "ss -tlnp | grep -E ':(80|443|6443|8080)'" 2>/dev/null || echo "无法获取端口信息"
    echo
    
    # 6. 日志检查
    echo "=== 系统日志 (最近10条错误) ==="
    $ssh_cmd "journalctl -p err -n 10 --no-pager" 2>/dev/null || echo "无法获取系统日志"
    echo
    
    log_success "系统诊断完成"
}

# 收集应用日志
collect_logs() {
    log_info "收集应用日志..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local namespace="final-ddd-${ENVIRONMENT}"
    local log_dir="/tmp/final-ddd-logs-$(date +%Y%m%d-%H%M%S)"
    
    # 创建远程日志目录
    $ssh_cmd "mkdir -p $log_dir"
    
    echo "=== 应用日志收集 ==="
    echo "环境: $ENVIRONMENT"
    echo "日志行数: $LOG_LINES"
    echo "保存位置: $log_dir"
    echo
    
    # 收集Pod日志
    if $ssh_cmd "kubectl get namespace $namespace >/dev/null 2>&1"; then
        local pods=$($ssh_cmd "kubectl get pods -n $namespace -o jsonpath='{.items[*].metadata.name}'" 2>/dev/null)
        
        for pod in $pods; do
            echo "收集Pod日志: $pod"
            $ssh_cmd "kubectl logs --tail=$LOG_LINES $pod -n $namespace > $log_dir/$pod.log 2>&1" || echo "无法收集 $pod 日志"
            
            # 收集之前的日志 (如果Pod重启过)
            $ssh_cmd "kubectl logs --previous --tail=$LOG_LINES $pod -n $namespace > $log_dir/$pod-previous.log 2>&1" || echo "无之前日志: $pod"
        done
    fi
    
    # 收集系统日志
    echo "收集系统日志..."
    $ssh_cmd "journalctl -u k3s -n $LOG_LINES --no-pager > $log_dir/k3s.log 2>&1" || echo "无法收集k3s日志"
    $ssh_cmd "journalctl -u docker -n $LOG_LINES --no-pager > $log_dir/docker.log 2>&1" || echo "无法收集docker日志"
    
    # 收集事件
    echo "收集Kubernetes事件..."
    $ssh_cmd "kubectl get events -n $namespace --sort-by='.lastTimestamp' > $log_dir/events.log 2>&1" || echo "无法收集事件"
    
    # 创建压缩包
    $ssh_cmd "cd $(dirname $log_dir) && tar -czf $(basename $log_dir).tar.gz $(basename $log_dir)"
    
    log_success "日志收集完成: $log_dir.tar.gz"
    
    # 显示日志摘要
    echo
    echo "=== 日志摘要 ==="
    $ssh_cmd "ls -la $log_dir/"
}#
 检查服务状态
check_service_status() {
    log_info "检查服务状态..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local namespace="final-ddd-${ENVIRONMENT}"
    
    echo "=== 服务状态检查 ==="
    
    # 检查k3s服务
    echo "k3s服务状态:"
    if $ssh_cmd "systemctl is-active k3s >/dev/null 2>&1"; then
        log_success "k3s服务: 运行中"
    else
        log_error "k3s服务: 未运行"
        if [[ "$AUTO_FIX" == "true" ]]; then
            log_info "尝试启动k3s服务..."
            $ssh_cmd "systemctl start k3s"
        fi
    fi
    
    # 检查Docker服务
    echo "Docker服务状态:"
    if $ssh_cmd "systemctl is-active docker >/dev/null 2>&1"; then
        log_success "Docker服务: 运行中"
    else
        log_error "Docker服务: 未运行"
        if [[ "$AUTO_FIX" == "true" ]]; then
            log_info "尝试启动Docker服务..."
            $ssh_cmd "systemctl start docker"
        fi
    fi
    
    # 检查应用Pod状态
    if $ssh_cmd "kubectl get namespace $namespace >/dev/null 2>&1"; then
        echo "应用Pod状态:"
        local pods=$($ssh_cmd "kubectl get pods -n $namespace -o jsonpath='{.items[*].metadata.name}'" 2>/dev/null)
        
        for pod in $pods; do
            local status=$($ssh_cmd "kubectl get pod $pod -n $namespace -o jsonpath='{.status.phase}'" 2>/dev/null)
            local ready=$($ssh_cmd "kubectl get pod $pod -n $namespace -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'" 2>/dev/null)
            
            if [[ "$status" == "Running" && "$ready" == "True" ]]; then
                log_success "Pod $pod: 运行正常"
            else
                log_error "Pod $pod: 状态异常 ($status, Ready: $ready)"
                
                if [[ "$AUTO_FIX" == "true" ]]; then
                    log_info "尝试重启Pod $pod..."
                    $ssh_cmd "kubectl delete pod $pod -n $namespace"
                fi
            fi
        done
    fi
    
    echo
}

# 重启服务
restart_services() {
    log_info "重启服务..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local namespace="final-ddd-${ENVIRONMENT}"
    
    echo "=== 服务重启 ==="
    
    # 确认重启操作
    if [[ "$AUTO_FIX" != "true" ]]; then
        read -p "确认重启 $ENVIRONMENT 环境的服务? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "重启操作已取消"
            return 0
        fi
    fi
    
    # 重启应用部署
    if $ssh_cmd "kubectl get namespace $namespace >/dev/null 2>&1"; then
        local deployments=$($ssh_cmd "kubectl get deployments -n $namespace -o jsonpath='{.items[*].metadata.name}'" 2>/dev/null)
        
        for deployment in $deployments; do
            log_info "重启部署: $deployment"
            $ssh_cmd "kubectl rollout restart deployment/$deployment -n $namespace"
        done
        
        # 等待重启完成
        for deployment in $deployments; do
            log_info "等待部署完成: $deployment"
            $ssh_cmd "kubectl rollout status deployment/$deployment -n $namespace --timeout=300s"
        done
    fi
    
    log_success "服务重启完成"
}

# 清理系统资源
cleanup_system() {
    log_info "清理系统资源..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    echo "=== 系统清理 ==="
    
    # 确认清理操作
    if [[ "$AUTO_FIX" != "true" ]]; then
        read -p "确认清理系统资源? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "清理操作已取消"
            return 0
        fi
    fi
    
    # 清理Docker资源
    if $ssh_cmd "command -v docker >/dev/null 2>&1"; then
        log_info "清理Docker资源..."
        
        # 清理未使用的镜像
        $ssh_cmd "docker image prune -f" || log_warning "清理Docker镜像失败"
        
        # 清理未使用的容器
        $ssh_cmd "docker container prune -f" || log_warning "清理Docker容器失败"
        
        # 清理未使用的网络
        $ssh_cmd "docker network prune -f" || log_warning "清理Docker网络失败"
        
        # 清理未使用的卷
        $ssh_cmd "docker volume prune -f" || log_warning "清理Docker卷失败"
    fi
    
    # 清理系统缓存
    log_info "清理系统缓存..."
    $ssh_cmd "sync && echo 3 > /proc/sys/vm/drop_caches" || log_warning "清理系统缓存失败"
    
    # 清理临时文件
    log_info "清理临时文件..."
    $ssh_cmd "find /tmp -type f -atime +7 -delete" || log_warning "清理临时文件失败"
    
    # 清理日志文件
    log_info "清理旧日志文件..."
    $ssh_cmd "journalctl --vacuum-time=7d" || log_warning "清理系统日志失败"
    
    log_success "系统清理完成"
}

# 修复常见问题
fix_common_issues() {
    log_info "修复常见问题..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local namespace="final-ddd-${ENVIRONMENT}"
    
    echo "=== 常见问题修复 ==="
    
    # 1. 修复Docker权限问题
    if $ssh_cmd "command -v docker >/dev/null 2>&1"; then
        if ! $ssh_cmd "docker ps >/dev/null 2>&1"; then
            log_info "修复Docker权限问题..."
            $ssh_cmd "systemctl restart docker"
            $ssh_cmd "usermod -aG docker $REMOTE_USER" || log_warning "无法添加用户到docker组"
        fi
    fi
    
    # 2. 修复k3s连接问题
    if $ssh_cmd "command -v kubectl >/dev/null 2>&1"; then
        if ! $ssh_cmd "kubectl cluster-info >/dev/null 2>&1"; then
            log_info "修复k3s连接问题..."
            $ssh_cmd "systemctl restart k3s"
            sleep 10
            
            # 重新配置kubeconfig
            $ssh_cmd "mkdir -p ~/.kube"
            $ssh_cmd "cp /etc/rancher/k3s/k3s.yaml ~/.kube/config"
            $ssh_cmd "chown $REMOTE_USER:$REMOTE_USER ~/.kube/config"
        fi
    fi
    
    # 3. 修复Pod镜像拉取问题
    if $ssh_cmd "kubectl get namespace $namespace >/dev/null 2>&1"; then
        local failed_pods=$($ssh_cmd "kubectl get pods -n $namespace --field-selector=status.phase=Failed -o jsonpath='{.items[*].metadata.name}'" 2>/dev/null)
        
        for pod in $failed_pods; do
            local reason=$($ssh_cmd "kubectl get pod $pod -n $namespace -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'" 2>/dev/null)
            
            if [[ "$reason" == "ImagePullBackOff" || "$reason" == "ErrImagePull" ]]; then
                log_info "修复Pod镜像拉取问题: $pod"
                $ssh_cmd "kubectl delete pod $pod -n $namespace"
            fi
        done
    fi
    
    # 4. 修复磁盘空间问题
    local disk_usage=$($ssh_cmd "df / | awk 'NR==2{print \$5}' | cut -d'%' -f1")
    if [[ $disk_usage -gt 80 ]]; then
        log_warning "磁盘使用率过高: ${disk_usage}%"
        log_info "执行磁盘清理..."
        cleanup_system
    fi
    
    # 5. 修复内存不足问题
    local mem_usage=$($ssh_cmd "free | awk 'NR==2{printf \"%.0f\", \$3/\$2*100}'")
    if [[ $mem_usage -gt 90 ]]; then
        log_warning "内存使用率过高: ${mem_usage}%"
        log_info "重启高内存使用的Pod..."
        
        if $ssh_cmd "kubectl get namespace $namespace >/dev/null 2>&1"; then
            $ssh_cmd "kubectl rollout restart deployment -n $namespace"
        fi
    fi
    
    log_success "常见问题修复完成"
}

# 主函数
main() {
    echo "=== 远程故障排除工具 ==="
    echo
    
    parse_args "$@"
    validate_config
    
    # 测试SSH连接
    if ! test_ssh_connection; then
        exit 1
    fi
    
    # 执行相应操作
    case "$ACTION" in
        diagnose)
            diagnose_system
            ;;
        logs)
            collect_logs
            ;;
        status)
            check_service_status
            ;;
        restart)
            restart_services
            ;;
        cleanup)
            cleanup_system
            ;;
        fix-common)
            fix_common_issues
            ;;
        *)
            log_error "未知操作: $ACTION"
            exit 1
            ;;
    esac
    
    log_success "故障排除操作完成: $ACTION"
}

# 执行主函数
main "$@"
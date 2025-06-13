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
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认值
ENVIRONMENT="dev"
SKIP_LOKI=false
SKIP_GRAFANA=false
SKIP_PROMTAIL=false

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -e, --env ENV             环境 (dev|staging|prod) [默认: dev]"
    echo "  --skip-loki               跳过 Loki 部署"
    echo "  --skip-grafana            跳过 Grafana 部署"
    echo "  --skip-promtail           跳过 Promtail 部署"
    echo "  --nomad-addr ADDR         Nomad 地址"
    echo
    echo "示例:"
    echo "  $0                        # 部署完整监控栈"
    echo "  $0 --skip-grafana         # 仅部署日志收集"
    echo "  $0 --env prod             # 部署到生产环境"
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
            --skip-loki)
                SKIP_LOKI=true
                shift
                ;;
            --skip-grafana)
                SKIP_GRAFANA=true
                shift
                ;;
            --skip-promtail)
                SKIP_PROMTAIL=true
                shift
                ;;
            --nomad-addr)
                NOMAD_ADDR="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 加载环境配置
load_environment() {
    local env_file="$DEPLOY_ROOT/configs/env/${ENVIRONMENT}.env"
    
    if [[ -f "$env_file" ]]; then
        echo -e "${BLUE}加载环境配置: $env_file${NC}"
        set -a
        source "$env_file"
        set +a
    else
        echo -e "${YELLOW}警告: 环境配置文件不存在: $env_file${NC}"
        echo "使用默认配置"
    fi
    
    # 设置默认值
    export GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
    export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin123}"
    export DOMAIN_NAME="${DOMAIN_NAME:-localhost}"
    
    [[ -n "$NOMAD_ADDR" ]] && export NOMAD_ADDR
}

# 创建数据目录
create_data_directories() {
    echo -e "${BLUE}创建监控数据目录...${NC}"
    
    local data_dirs=(
        "/opt/data/loki"
        "/opt/data/grafana"
        "/opt/data/promtail"
    )
    
    for dir in "${data_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "创建目录: $dir"
            sudo mkdir -p "$dir"
            sudo chmod 755 "$dir"
        fi
    done
    
    echo -e "${GREEN}监控数据目录创建完成${NC}"
}

# 部署单个作业
deploy_job() {
    local job_file="$1"
    local job_name=$(basename "$job_file" .nomad)
    
    echo -e "${YELLOW}部署作业: $job_name${NC}"
    
    # 使用 envsubst 替换环境变量
    local temp_file=$(mktemp)
    envsubst < "$job_file" > "$temp_file"
    
    nomad job run "$temp_file"
    echo -e "${GREEN}作业 $job_name 部署完成${NC}"
    
    rm -f "$temp_file"
}

# 等待服务健康
wait_for_service() {
    local service_name="$1"
    local timeout="${2:-60}"
    
    echo "等待 $service_name 服务健康检查..."
    local start_time=$(date +%s)
    
    while [[ $(($(date +%s) - start_time)) -lt $timeout ]]; do
        if nomad job status "$service_name" | grep -q "running"; then
            echo -e "${GREEN}$service_name 服务运行正常${NC}"
            return 0
        fi
        sleep 5
    done
    
    echo -e "${YELLOW}警告: $service_name 服务健康检查超时${NC}"
    return 1
}

# 主部署流程
main() {
    echo -e "${GREEN}开始部署日志监控栈${NC}"
    echo "========================================"
    
    parse_args "$@"
    load_environment
    create_data_directories
    
    # 检查 Nomad 是否可用
    if ! command -v nomad >/dev/null 2>&1; then
        echo -e "${RED}错误: Nomad 未安装${NC}"
        exit 1
    fi
    
    # 按顺序部署服务
    if [[ "$SKIP_LOKI" != "true" ]]; then
        deploy_job "$DEPLOY_ROOT/nomad/monitoring/loki.nomad"
        wait_for_service "loki" 60
    fi
    
    if [[ "$SKIP_PROMTAIL" != "true" ]]; then
        deploy_job "$DEPLOY_ROOT/nomad/monitoring/promtail.nomad"
        wait_for_service "promtail" 30
    fi
    
    if [[ "$SKIP_GRAFANA" != "true" ]]; then
        deploy_job "$DEPLOY_ROOT/nomad/monitoring/grafana.nomad"
        wait_for_service "grafana" 60
    fi
    
    echo -e "${GREEN}监控栈部署完成！${NC}"
    echo "========================================"
    echo "Grafana: https://grafana.${DOMAIN_NAME}"
    echo "  用户名: ${GRAFANA_ADMIN_USER}"
    echo "  密码: ${GRAFANA_ADMIN_PASSWORD}"
    echo
    echo "Loki: https://loki.${DOMAIN_NAME}"
    echo
    echo -e "${YELLOW}提示:${NC}"
    echo "1. 确保 Traefik 已部署并配置了域名解析"
    echo "2. 在 Grafana 中导入日志仪表板"
    echo "3. 配置应用程序输出 JSON 格式日志"
}

# 执行主函数
main "$@"

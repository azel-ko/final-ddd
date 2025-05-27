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
FORCE=false
CLEAN_DATA=false
CLEAN_IMAGES=false

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -e, --env ENV             环境 (dev|staging|prod) [默认: dev]"
    echo "  -f, --force               强制清理，不询问确认"
    echo "  -d, --clean-data          清理数据目录"
    echo "  -i, --clean-images        清理 Docker 镜像"
    echo "  --nomad-addr ADDR         Nomad 地址"
    echo
    echo "示例:"
    echo "  $0                        # 停止所有服务"
    echo "  $0 --clean-data           # 停止服务并清理数据"
    echo "  $0 --force --clean-images # 强制清理所有内容"
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
            -f|--force)
                FORCE=true
                shift
                ;;
            -d|--clean-data)
                CLEAN_DATA=true
                shift
                ;;
            -i|--clean-images)
                CLEAN_IMAGES=true
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
    fi
    
    # 命令行参数覆盖配置文件
    [[ -n "$NOMAD_ADDR" ]] && export NOMAD_ADDR
    
    echo "使用 Nomad 地址: ${NOMAD_ADDR:-http://localhost:4646}"
}

# 确认操作
confirm_action() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}即将执行以下清理操作:${NC}"
    echo "  - 停止所有 Nomad 作业"
    
    if [[ "$CLEAN_DATA" == "true" ]]; then
        echo "  - 清理数据目录 (/opt/data)"
    fi
    
    if [[ "$CLEAN_IMAGES" == "true" ]]; then
        echo "  - 清理 Docker 镜像"
    fi
    
    echo
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 0
    fi
}

# 停止 Nomad 作业
stop_nomad_jobs() {
    echo -e "${BLUE}停止 Nomad 作业...${NC}"
    
    # 获取所有作业
    local jobs=$(nomad job status -short | tail -n +2 | awk '{print $1}' | grep -v "^$" || true)
    
    if [[ -z "$jobs" ]]; then
        echo "没有运行中的作业"
        return
    fi
    
    for job in $jobs; do
        echo "停止作业: $job"
        nomad job stop "$job" || echo -e "${YELLOW}警告: 无法停止作业 $job${NC}"
    done
    
    # 等待作业完全停止
    echo "等待作业完全停止..."
    sleep 5
    
    # 清理已停止的作业
    for job in $jobs; do
        echo "清理作业: $job"
        nomad job stop -purge "$job" 2>/dev/null || true
    done
    
    echo -e "${GREEN}Nomad 作业清理完成${NC}"
}

# 清理数据目录
clean_data_directories() {
    if [[ "$CLEAN_DATA" != "true" ]]; then
        return
    fi
    
    echo -e "${BLUE}清理数据目录...${NC}"
    
    local data_dirs=(
        "/opt/data/traefik"
        "/opt/data/postgres"
        "/opt/data/registry"
        "/opt/data/app"
    )
    
    for dir in "${data_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "清理目录: $dir"
            sudo rm -rf "$dir"/*
        fi
    done
    
    echo -e "${GREEN}数据目录清理完成${NC}"
}

# 清理 Docker 镜像
clean_docker_images() {
    if [[ "$CLEAN_IMAGES" != "true" ]]; then
        return
    fi
    
    echo -e "${BLUE}清理 Docker 镜像...${NC}"
    
    # 清理项目相关镜像
    local project_images=$(docker images | grep -E "(final-ddd|localhost:5000/final-ddd)" | awk '{print $3}' || true)
    
    if [[ -n "$project_images" ]]; then
        echo "删除项目镜像..."
        docker rmi $project_images 2>/dev/null || true
    fi
    
    # 清理悬空镜像
    echo "清理悬空镜像..."
    docker image prune -f
    
    # 清理未使用的镜像
    echo "清理未使用的镜像..."
    docker image prune -a -f
    
    echo -e "${GREEN}Docker 镜像清理完成${NC}"
}

# 显示清理结果
show_cleanup_result() {
    echo -e "${GREEN}清理完成！${NC}"
    echo "========================================"
    
    echo -e "${BLUE}当前 Nomad 作业状态:${NC}"
    nomad job status || echo "无运行中的作业"
    
    if [[ "$CLEAN_IMAGES" == "true" ]]; then
        echo -e "${BLUE}当前 Docker 镜像:${NC}"
        docker images | grep -E "(final-ddd|localhost:5000)" || echo "无项目相关镜像"
    fi
    
    if [[ "$CLEAN_DATA" == "true" ]]; then
        echo -e "${BLUE}数据目录状态:${NC}"
        ls -la /opt/data/ 2>/dev/null || echo "数据目录不存在"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}开始清理 Final DDD 部署${NC}"
    echo "========================================"
    
    parse_args "$@"
    load_environment
    confirm_action
    
    # 检查 Nomad 是否可用
    if ! command -v nomad >/dev/null 2>&1; then
        echo -e "${RED}错误: Nomad 未安装${NC}"
        exit 1
    fi
    
    stop_nomad_jobs
    clean_data_directories
    clean_docker_images
    show_cleanup_result
}

# 执行主函数
main "$@"

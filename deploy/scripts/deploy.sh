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
ASYNC_DEPLOY=false
WAIT_TIMEOUT=60
SKIP_INFRASTRUCTURE=false
CLUSTER_MODE="auto"  # auto, single, cluster

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -e, --env ENV             设置环境 (dev|staging|prod) [默认: dev]"
    echo "  -d, --domain DOMAIN       设置应用域名"
    echo "  -f, --force-build         强制重新构建镜像"
    echo "  -a, --async               异步部署，不等待服务健康检查"
    echo "  -t, --timeout SECONDS     等待服务健康的超时时间 [默认: 60]"
    echo "  -s, --skip-infra          跳过基础设施部署"
    echo "  -c, --cluster-mode MODE   集群模式 (auto|single|cluster) [默认: auto]"
    echo "  --nomad-addr ADDR         Nomad 地址"
    echo "  --consul-addr ADDR        Consul 地址"
    echo
    echo "示例:"
    echo "  $0 --env dev                           # 部署到开发环境"
    echo "  $0 --env prod --domain example.com    # 部署到生产环境"
    echo "  $0 --force-build --async               # 强制构建并异步部署"
    echo "  $0 --cluster-mode single               # 强制单机模式"
    echo "  $0 --cluster-mode cluster              # 强制集群模式"
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
                DOMAIN_NAME="$2"
                shift 2
                ;;
            -f|--force-build)
                FORCE_BUILD=true
                shift
                ;;
            -a|--async)
                ASYNC_DEPLOY=true
                shift
                ;;
            -t|--timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            -s|--skip-infra)
                SKIP_INFRASTRUCTURE=true
                shift
                ;;
            -c|--cluster-mode)
                CLUSTER_MODE="$2"
                shift 2
                ;;
            --nomad-addr)
                NOMAD_ADDR="$2"
                shift 2
                ;;
            --consul-addr)
                CONSUL_ADDR="$2"
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

    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}错误: 环境配置文件不存在: $env_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}加载环境配置: $env_file${NC}"

    # 导出环境变量
    set -a
    source "$env_file"
    set +a

    # 命令行参数覆盖配置文件
    [[ -n "$DOMAIN_NAME" ]] && export DOMAIN_NAME
    [[ -n "$NOMAD_ADDR" ]] && export NOMAD_ADDR
    [[ -n "$CONSUL_ADDR" ]] && export CONSUL_ADDR

    echo -e "${GREEN}环境配置加载完成${NC}"
    echo "  环境: $APP_ENV"
    echo "  域名: $DOMAIN_NAME"
    echo "  Nomad: $NOMAD_ADDR"
    echo "  Consul: $CONSUL_ADDR"
}

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查依赖工具...${NC}"

    local missing_tools=()

    command -v nomad >/dev/null 2>&1 || missing_tools+=("nomad")
    command -v consul >/dev/null 2>&1 || missing_tools+=("consul")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}错误: 缺少必要工具: ${missing_tools[*]}${NC}"
        echo "请安装缺少的工具后重试"
        exit 1
    fi

    echo -e "${GREEN}所有依赖工具已安装${NC}"
}

# 检测集群模式
detect_cluster_mode() {
    if [[ "$CLUSTER_MODE" != "auto" ]]; then
        echo -e "${BLUE}使用指定的集群模式: $CLUSTER_MODE${NC}"
        return
    fi

    echo -e "${BLUE}自动检测集群模式...${NC}"

    # 检查 Nomad 节点数量
    local node_count=$(nomad node status -short 2>/dev/null | tail -n +2 | wc -l || echo "0")

    if [[ $node_count -gt 1 ]]; then
        CLUSTER_MODE="cluster"
        echo -e "${GREEN}检测到多节点环境，使用集群模式${NC}"
    else
        CLUSTER_MODE="single"
        echo -e "${GREEN}检测到单节点环境，使用单机模式${NC}"
    fi

    echo "节点数量: $node_count"
    echo "集群模式: $CLUSTER_MODE"

    # 导出环境变量供 Nomad 作业使用
    export CLUSTER_MODE
}

# 创建数据目录
create_data_directories() {
    echo -e "${BLUE}创建数据目录...${NC}"

    local data_dirs=(
        "/opt/data/traefik"
        "/opt/data/postgres"
        "/opt/data/registry"
        "/opt/data/app"
    )

    if [[ "$CLUSTER_MODE" == "cluster" ]]; then
        echo -e "${YELLOW}集群模式: 请确保所有节点都已创建以下目录:${NC}"
        for dir in "${data_dirs[@]}"; do
            echo "  $dir"
        done
        echo -e "${YELLOW}建议在所有节点上运行以下命令:${NC}"
        echo "  sudo mkdir -p ${data_dirs[*]}"
        echo "  sudo chmod -R 755 /opt/data"
        echo
        read -p "是否继续部署? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "部署已取消"
            exit 0
        fi
    else
        # 单机模式，直接创建目录
        for dir in "${data_dirs[@]}"; do
            if [[ ! -d "$dir" ]]; then
                echo "创建目录: $dir"
                sudo mkdir -p "$dir"
                sudo chmod 755 "$dir"
            fi
        done
    fi

    echo -e "${GREEN}数据目录检查完成${NC}"
}

# 构建应用镜像
build_application() {
    echo -e "${BLUE}构建应用镜像...${NC}"

    local image_tag="${APP_IMAGE}"
    local local_image="final-ddd:latest"

    # 检查是否需要构建
    if [[ "$FORCE_BUILD" == "false" ]] && docker image inspect "$local_image" >/dev/null 2>&1; then
        echo "镜像 $local_image 已存在，跳过构建"
    else
        echo "构建镜像: $local_image"
        cd "$PROJECT_ROOT"

        # 获取版本信息
        local version=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
        local build_time=$(date -u '+%Y-%m-%d %H:%M:%S')
        local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

        docker build \
            --build-arg VERSION="$version" \
            --build-arg BUILD_TIME="$build_time" \
            --build-arg COMMIT_HASH="$commit_hash" \
            -t "$local_image" \
            .
    fi

    # 如果使用本地 Registry，标记并推送镜像
    if [[ "$USE_LOCAL_REGISTRY" == "true" ]]; then
        echo "标记镜像: $image_tag"
        docker tag "$local_image" "$image_tag"
    fi

    echo -e "${GREEN}应用镜像构建完成${NC}"
}

# 部署单个作业
deploy_job() {
    local job_file="$1"
    local job_name=$(basename "$job_file" .nomad)

    echo -e "${YELLOW}部署作业: $job_name${NC}"

    # 使用 envsubst 替换环境变量
    local temp_file=$(mktemp)
    envsubst < "$job_file" > "$temp_file"

    if [[ "$ASYNC_DEPLOY" == "true" ]]; then
        nomad job run -detach "$temp_file"
        echo -e "${GREEN}作业 $job_name 已提交${NC}"
    else
        nomad job run "$temp_file"
        echo -e "${GREEN}作业 $job_name 部署完成${NC}"

        # 等待服务健康
        echo "等待 $job_name 服务健康检查..."
        local start_time=$(date +%s)
        while [[ $(($(date +%s) - start_time)) -lt $WAIT_TIMEOUT ]]; do
            if nomad job status "$job_name" | grep -q "running"; then
                echo -e "${GREEN}$job_name 服务运行正常${NC}"
                break
            fi
            sleep 5
        done
    fi

    rm -f "$temp_file"
}

# 主部署流程
main() {
    echo -e "${GREEN}开始部署 Final DDD 应用${NC}"
    echo "========================================"

    parse_args "$@"
    load_environment
    check_dependencies
    detect_cluster_mode
    create_data_directories
    build_application

    # 部署基础设施
    if [[ "$SKIP_INFRASTRUCTURE" == "false" ]]; then
        echo -e "${BLUE}部署基础设施服务...${NC}"

        # 根据集群模式选择配置文件
        local traefik_config="$DEPLOY_ROOT/nomad/infrastructure/traefik.nomad"
        local postgres_config="$DEPLOY_ROOT/nomad/infrastructure/postgres.nomad"
        local registry_config="$DEPLOY_ROOT/nomad/infrastructure/registry.nomad"
        local app_config="$DEPLOY_ROOT/nomad/applications/app.nomad"

        if [[ "$CLUSTER_MODE" == "single" ]]; then
            traefik_config="$DEPLOY_ROOT/nomad/infrastructure/traefik-single.nomad"
            postgres_config="$DEPLOY_ROOT/nomad/infrastructure/postgres-single.nomad"
            registry_config="$DEPLOY_ROOT/nomad/infrastructure/registry-single.nomad"
            app_config="$DEPLOY_ROOT/nomad/applications/app-single.nomad"
            echo -e "${YELLOW}使用单机模式配置文件${NC}"
        else
            echo -e "${YELLOW}使用集群模式配置文件${NC}"
        fi

        # 按顺序部署基础设施
        deploy_job "$traefik_config"
        deploy_job "$postgres_config"

        if [[ "$USE_LOCAL_REGISTRY" == "true" ]]; then
            deploy_job "$registry_config"

            # 等待 Registry 启动后推送镜像
            echo "等待 Registry 服务启动..."
            sleep 10

            echo "推送镜像到本地 Registry..."
            docker push "$APP_IMAGE"
        fi

        # 部署应用
        echo -e "${BLUE}部署应用服务...${NC}"
        deploy_job "$app_config"
    else
        # 仅部署应用
        echo -e "${BLUE}部署应用服务...${NC}"
        local app_config="$DEPLOY_ROOT/nomad/applications/app.nomad"
        if [[ "$CLUSTER_MODE" == "single" ]]; then
            app_config="$DEPLOY_ROOT/nomad/applications/app-single.nomad"
        fi
        deploy_job "$app_config"
    fi

    echo -e "${GREEN}部署完成！${NC}"
    echo "========================================"
    echo "应用访问地址: https://$DOMAIN_NAME"
    echo "Nomad UI: $NOMAD_ADDR"
    echo "Consul UI: $CONSUL_ADDR"

    if [[ "$ASYNC_DEPLOY" == "true" ]]; then
        echo -e "${YELLOW}注意: 使用异步部署模式，请检查服务状态${NC}"
    fi
}

# 执行主函数
main "$@"

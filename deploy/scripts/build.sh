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

# 默认值
IMAGE_NAME="final-ddd"
IMAGE_TAG="latest"
PUSH_TO_REGISTRY=false
REGISTRY_URL=""

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -n, --name NAME           镜像名称 [默认: final-ddd]"
    echo "  -t, --tag TAG             镜像标签 [默认: latest]"
    echo "  -p, --push                推送到镜像仓库"
    echo "  -r, --registry URL        镜像仓库地址"
    echo
    echo "示例:"
    echo "  $0                                    # 构建本地镜像"
    echo "  $0 --tag v1.0.0                      # 构建指定标签"
    echo "  $0 --push --registry localhost:5000  # 构建并推送到本地仓库"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            -t|--tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            -p|--push)
                PUSH_TO_REGISTRY=true
                shift
                ;;
            -r|--registry)
                REGISTRY_URL="$2"
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

# 检查 Docker
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}错误: Docker 未安装${NC}"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}错误: Docker 服务未运行${NC}"
        exit 1
    fi
}

# 获取版本信息
get_version_info() {
    cd "$PROJECT_ROOT"
    
    VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
    BUILD_TIME=$(date -u '+%Y-%m-%d %H:%M:%S')
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    echo -e "${BLUE}版本信息:${NC}"
    echo "  版本: $VERSION"
    echo "  构建时间: $BUILD_TIME"
    echo "  提交哈希: $COMMIT_HASH"
}

# 构建镜像
build_image() {
    local full_image_name="$IMAGE_NAME:$IMAGE_TAG"
    
    if [[ -n "$REGISTRY_URL" ]]; then
        full_image_name="$REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG"
    fi
    
    echo -e "${BLUE}构建镜像: $full_image_name${NC}"
    
    cd "$PROJECT_ROOT"
    
    docker build \
        --build-arg VERSION="$VERSION" \
        --build-arg BUILD_TIME="$BUILD_TIME" \
        --build-arg COMMIT_HASH="$COMMIT_HASH" \
        -t "$full_image_name" \
        -t "$IMAGE_NAME:latest" \
        .
    
    echo -e "${GREEN}镜像构建完成: $full_image_name${NC}"
    
    # 显示镜像信息
    docker images | grep "$IMAGE_NAME" | head -5
}

# 推送镜像
push_image() {
    if [[ "$PUSH_TO_REGISTRY" == "true" ]]; then
        if [[ -z "$REGISTRY_URL" ]]; then
            echo -e "${RED}错误: 推送镜像需要指定仓库地址${NC}"
            exit 1
        fi
        
        local full_image_name="$REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG"
        
        echo -e "${BLUE}推送镜像: $full_image_name${NC}"
        
        # 检查仓库是否可访问
        if ! curl -s "$REGISTRY_URL/v2/" >/dev/null 2>&1; then
            echo -e "${YELLOW}警告: 无法访问镜像仓库 $REGISTRY_URL${NC}"
            echo "请确保仓库服务正在运行"
        fi
        
        docker push "$full_image_name"
        
        echo -e "${GREEN}镜像推送完成: $full_image_name${NC}"
    fi
}

# 清理旧镜像
cleanup_old_images() {
    echo -e "${BLUE}清理悬空镜像...${NC}"
    
    # 删除悬空镜像
    if docker images -f "dangling=true" -q | grep -q .; then
        docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
        echo -e "${GREEN}悬空镜像清理完成${NC}"
    else
        echo "没有悬空镜像需要清理"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}开始构建 Final DDD 应用镜像${NC}"
    echo "========================================"
    
    parse_args "$@"
    check_docker
    get_version_info
    build_image
    push_image
    cleanup_old_images
    
    echo -e "${GREEN}构建完成！${NC}"
    echo "========================================"
    
    if [[ -n "$REGISTRY_URL" ]]; then
        echo "镜像地址: $REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG"
    else
        echo "本地镜像: $IMAGE_NAME:$IMAGE_TAG"
    fi
}

# 执行主函数
main "$@"

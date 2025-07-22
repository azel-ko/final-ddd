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
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认值
BUILD_TARGET="all"  # all, frontend, backend, docker
IMAGE_NAME="final-ddd"
IMAGE_TAG="latest"
PUSH_TO_REGISTRY=false
REGISTRY_URL="localhost:5000"
SKIP_TESTS=false
PARALLEL_BUILD=true

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help                显示帮助信息"
    echo "  -t, --target TARGET       构建目标 (all|frontend|backend|docker) [默认: all]"
    echo "  -n, --name NAME           Docker 镜像名称 [默认: final-ddd]"
    echo "  --tag TAG                 Docker 镜像标签 [默认: latest]"
    echo "  -p, --push                推送到镜像仓库"
    echo "  -r, --registry URL        镜像仓库地址 [默认: localhost:5000]"
    echo "  --skip-tests              跳过测试"
    echo "  --no-parallel             禁用并行构建"
    echo
    echo "构建目标说明:"
    echo "  all       - 构建前端和后端 (默认)"
    echo "  frontend  - 仅构建前端"
    echo "  backend   - 仅构建后端"
    echo "  docker    - 构建 Docker 镜像"
    echo
    echo "示例:"
    echo "  $0                                    # 构建前端和后端"
    echo "  $0 --target docker --push            # 构建并推送 Docker 镜像"
    echo "  $0 --target frontend                 # 仅构建前端"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--target)
                BUILD_TARGET="$2"
                shift 2
                ;;
            -n|--name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            --tag)
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
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --no-parallel)
                PARALLEL_BUILD=false
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

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查构建依赖...${NC}"
    
    local missing_deps=()
    
    if [[ "$BUILD_TARGET" == "all" || "$BUILD_TARGET" == "frontend" ]]; then
        command -v pnpm >/dev/null 2>&1 || missing_deps+=("pnpm")
        command -v node >/dev/null 2>&1 || missing_deps+=("node")
    fi
    
    if [[ "$BUILD_TARGET" == "all" || "$BUILD_TARGET" == "backend" ]]; then
        command -v go >/dev/null 2>&1 || missing_deps+=("go")
    fi
    
    if [[ "$BUILD_TARGET" == "docker" ]]; then
        command -v docker >/dev/null 2>&1 || missing_deps+=("docker")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}错误: 缺少以下依赖: ${missing_deps[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}依赖检查通过${NC}"
}

# 获取版本信息
get_version_info() {
    VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
    BUILD_TIME=$(date -u '+%Y-%m-%d %H:%M:%S')
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    echo -e "${BLUE}版本信息:${NC}"
    echo "  版本: $VERSION"
    echo "  构建时间: $BUILD_TIME"
    echo "  提交哈希: $COMMIT_HASH"
}

# 构建前端
build_frontend() {
    echo -e "${BLUE}构建前端应用...${NC}"
    cd "$PROJECT_ROOT/frontend"

    # 检查 node_modules 是否存在
    if [ ! -d "node_modules" ]; then
        echo "安装前端依赖..."
        pnpm install
    fi

    # 构建前端
    echo "编译前端代码..."
    pnpm run build

    # 确保目标目录存在
    mkdir -p "$PROJECT_ROOT/internal/interfaces/http/router/frontend/dist"

    # 复制构建文件到嵌入目录
    echo "复制前端构建文件到嵌入目录..."
    cp -r dist/* "$PROJECT_ROOT/internal/interfaces/http/router/frontend/dist/"

    echo -e "${GREEN}前端构建完成${NC}"
}

# 构建后端
build_backend() {
    echo -e "${BLUE}构建后端应用...${NC}"
    cd "$PROJECT_ROOT"

    # 运行测试 (如果未跳过)
    if [[ "$SKIP_TESTS" != "true" ]]; then
        echo "运行单元测试..."
        go test -v ./...
    fi

    # 构建二进制文件
    echo "编译 Go 代码..."
    go build -ldflags "
        -X 'github.com/azel-ko/final-ddd/internal/pkg/version.Version=$VERSION'
        -X 'github.com/azel-ko/final-ddd/internal/pkg/version.BuildTime=$BUILD_TIME'
        -X 'github.com/azel-ko/final-ddd/internal/pkg/version.CommitHash=$COMMIT_HASH'
    " -o final-ddd ./cmd/main.go

    echo -e "${GREEN}后端构建完成: final-ddd${NC}"
}

# 构建 Docker 镜像
build_docker() {
    echo -e "${BLUE}构建 Docker 镜像...${NC}"
    cd "$PROJECT_ROOT"

    # 确保应用已构建
    if [[ ! -f "final-ddd" ]]; then
        echo "二进制文件不存在，先构建应用..."
        build_backend
    fi

    # 构建 Docker 镜像
    echo "构建 Docker 镜像: $IMAGE_NAME:$IMAGE_TAG"
    docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
    
    # 如果指定了版本标签，也打上版本标签
    if [[ "$IMAGE_TAG" != "$VERSION" && "$VERSION" != "unknown" ]]; then
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$IMAGE_NAME:$VERSION"
        echo "已标记版本: $IMAGE_NAME:$VERSION"
    fi

    # 推送到仓库
    if [[ "$PUSH_TO_REGISTRY" == "true" ]]; then
        echo "推送镜像到仓库: $REGISTRY_URL"
        
        # 重新标记为仓库地址
        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG"
        docker push "$REGISTRY_URL/$IMAGE_NAME:$IMAGE_TAG"
        
        if [[ "$IMAGE_TAG" != "$VERSION" && "$VERSION" != "unknown" ]]; then
            docker tag "$IMAGE_NAME:$VERSION" "$REGISTRY_URL/$IMAGE_NAME:$VERSION"
            docker push "$REGISTRY_URL/$IMAGE_NAME:$VERSION"
        fi
        
        echo -e "${GREEN}镜像推送完成${NC}"
    fi

    echo -e "${GREEN}Docker 镜像构建完成${NC}"
}

# 清理构建产物
clean_build() {
    echo -e "${BLUE}清理构建产物...${NC}"
    
    rm -f final-ddd
    rm -rf build/
    rm -f coverage.out coverage.html
    
    if [[ -d "frontend/dist" ]]; then
        rm -rf frontend/dist/
    fi
    
    if [[ -d "internal/interfaces/http/router/frontend/dist" ]]; then
        rm -rf internal/interfaces/http/router/frontend/dist/
    fi
    
    echo -e "${GREEN}清理完成${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}=== Final DDD 构建脚本 ===${NC}"
    
    parse_args "$@"
    check_dependencies
    get_version_info
    
    case $BUILD_TARGET in
        frontend)
            build_frontend
            ;;
        backend)
            build_backend
            ;;
        docker)
            # Docker 构建需要先构建应用
            if [[ "$PARALLEL_BUILD" == "true" ]]; then
                build_frontend &
                build_backend &
                wait
            else
                build_frontend
                build_backend
            fi
            build_docker
            ;;
        all)
            if [[ "$PARALLEL_BUILD" == "true" ]]; then
                build_frontend &
                build_backend &
                wait
            else
                build_frontend
                build_backend
            fi
            ;;
        clean)
            clean_build
            ;;
        *)
            echo -e "${RED}未知的构建目标: $BUILD_TARGET${NC}"
            show_help
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}=== 构建完成 ===${NC}"
}

# 如果直接运行脚本，执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
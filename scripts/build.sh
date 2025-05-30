#!/bin/bash

set -e

# 显示构建信息
echo "开始构建一体化应用..."

# 确保在项目根目录
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# 构建前端
echo "步骤 1: 构建前端应用..."
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

# 返回项目根目录
cd "$PROJECT_ROOT"

# 构建后端
echo "步骤 2: 构建后端应用..."

# 获取当前版本信息
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
BUILD_TIME=$(date -u '+%Y-%m-%d %H:%M:%S')
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# 构建二进制文件
echo "编译 Go 代码..."
go build -ldflags "-X 'github.com/azel-ko/final-ddd/pkg/version.Version=$VERSION' -X 'github.com/azel-ko/final-ddd/pkg/version.BuildTime=$BUILD_TIME' -X 'github.com/azel-ko/final-ddd/pkg/version.CommitHash=$COMMIT_HASH'" -o final-ddd ./cmd/main.go

echo "构建完成！生成的二进制文件: final-ddd"
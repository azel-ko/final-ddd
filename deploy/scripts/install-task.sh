#!/bin/bash

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查是否已安装 Task
if command -v task >/dev/null 2>&1; then
    echo -e "${GREEN}Task 已安装: $(task --version)${NC}"
    exit 0
fi

echo -e "${BLUE}安装 Task runner...${NC}"

# 检测操作系统和架构
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="arm"
        ;;
    *)
        echo -e "${RED}不支持的架构: $ARCH${NC}"
        exit 1
        ;;
esac

# 获取最新版本
LATEST_VERSION=$(curl -s https://api.github.com/repos/go-task/task/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${RED}无法获取最新版本信息${NC}"
    exit 1
fi

echo "最新版本: $LATEST_VERSION"

# 下载 Task
DOWNLOAD_URL="https://github.com/go-task/task/releases/download/${LATEST_VERSION}/task_${OS}_${ARCH}.tar.gz"
TEMP_DIR=$(mktemp -d)

echo "下载 Task..."
curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/task.tar.gz"

# 解压
cd "$TEMP_DIR"
tar -xzf task.tar.gz

# 安装
if [ -w "/usr/local/bin" ]; then
    sudo mv task /usr/local/bin/
else
    echo -e "${YELLOW}需要 sudo 权限安装到 /usr/local/bin${NC}"
    sudo mv task /usr/local/bin/
fi

# 清理
rm -rf "$TEMP_DIR"

# 验证安装
if command -v task >/dev/null 2>&1; then
    echo -e "${GREEN}Task 安装成功: $(task --version)${NC}"
    echo
    echo "使用方法:"
    echo "  task --list          # 查看所有可用任务"
    echo "  task setup           # 设置开发环境"
    echo "  task build:all       # 构建应用"
    echo "  task deploy:dev      # 部署到开发环境"
else
    echo -e "${RED}Task 安装失败${NC}"
    exit 1
fi
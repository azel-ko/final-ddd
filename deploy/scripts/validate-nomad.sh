#!/bin/bash

# Nomad 配置文件验证脚本

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

echo -e "${BLUE}验证 Nomad 配置文件...${NC}"

# 检查 Nomad 是否安装
if ! command -v nomad >/dev/null 2>&1; then
    echo -e "${YELLOW}警告: Nomad 未安装，跳过语法验证${NC}"
    echo -e "${BLUE}仅检查文件存在性...${NC}"
    
    # 检查配置文件是否存在
    config_files=(
        "nomad/infrastructure/traefik.nomad"
        "nomad/infrastructure/traefik-single.nomad"
        "nomad/infrastructure/postgres.nomad"
        "nomad/infrastructure/postgres-single.nomad"
        "nomad/infrastructure/registry.nomad"
        "nomad/infrastructure/registry-single.nomad"
        "nomad/applications/app.nomad"
        "nomad/applications/app-single.nomad"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$DEPLOY_ROOT/$config_file" ]]; then
            echo -e "${GREEN}✓${NC} $config_file"
        else
            echo -e "${RED}✗${NC} $config_file (文件不存在)"
        fi
    done
    
    echo -e "${GREEN}文件检查完成${NC}"
    exit 0
fi

# 如果 Nomad 已安装，进行语法验证
echo -e "${BLUE}使用 Nomad 进行语法验证...${NC}"

config_files=(
    "nomad/infrastructure/traefik.nomad"
    "nomad/infrastructure/traefik-single.nomad"
    "nomad/infrastructure/postgres.nomad"
    "nomad/infrastructure/postgres-single.nomad"
    "nomad/infrastructure/registry.nomad"
    "nomad/infrastructure/registry-single.nomad"
    "nomad/applications/app.nomad"
    "nomad/applications/app-single.nomad"
)

failed_files=()

for config_file in "${config_files[@]}"; do
    echo -n "验证 $config_file ... "
    
    if nomad job validate "$DEPLOY_ROOT/$config_file" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        failed_files+=("$config_file")
        echo -e "${RED}错误详情:${NC}"
        nomad job validate "$DEPLOY_ROOT/$config_file" 2>&1 | sed 's/^/  /'
        echo
    fi
done

if [[ ${#failed_files[@]} -eq 0 ]]; then
    echo -e "${GREEN}所有 Nomad 配置文件验证通过！${NC}"
    exit 0
else
    echo -e "${RED}以下配置文件验证失败:${NC}"
    for file in "${failed_files[@]}"; do
        echo -e "${RED}  - $file${NC}"
    done
    exit 1
fi

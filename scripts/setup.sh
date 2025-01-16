#!/bin/bash

# 检查是否安装了 docker-compose
if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi


# 检查是否提供了配置文件路径参数，如果没有提供则使用默认路径
CONFIG_FILE=${1:-"../configs/config.yml"}

# 检查提供的文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found at $CONFIG_FILE" >&2
  exit 1
fi


# 定义环境变量（如果需要的话）
export DATABASE_SERVICE=$(yq e '.database.type' "$CONFIG_FILE")
export DB_USER=$(yq e '.database.user' "$CONFIG_FILE")
export DB_PASSWORD=$(yq e '.database.password' "$CONFIG_FILE")
export DB_PORT=$(yq e '.database.port' "$CONFIG_FILE")
export DB_NAME=$(yq e '.database.name' "$CONFIG_FILE")
export DB_PATH=$(yq e '.database.path' "$CONFIG_FILE")

# 打印环境变量以验证（可选）
echo "Environment variables have been set from $CONFIG_FILE:"
printenv | grep -E 'DATABASE_'

# 启动 Docker Compose 服务
docker-compose -f ..docker/docker-compose.yml up -d

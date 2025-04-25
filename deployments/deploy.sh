#!/bin/bash
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 默认值
NOMAD_ADDR=${NOMAD_ADDR:-"http://localhost:4646"}
CONSUL_ADDR=${CONSUL_ADDR:-"http://localhost:8500"}
DOMAIN_NAME=${DOMAIN_NAME:-"example.com"}
CLUSTER_MODE=${CLUSTER_MODE:-"false"}

# 显示帮助信息
show_help() {
  echo "用法: $0 [选项]"
  echo
  echo "选项:"
  echo "  -h, --help                显示帮助信息"
  echo "  -n, --nomad-addr ADDR     设置 Nomad 地址 (默认: http://localhost:4646)"
  echo "  -c, --consul-addr ADDR    设置 Consul 地址 (默认: http://localhost:8500)"
  echo "  -d, --domain DOMAIN       设置应用域名 (默认: example.com)"
  echo "  --cluster                 启用集群模式 (默认: 禁用)"
  echo "  --database SERVICE        设置数据库服务 (mysql, postgres, sqlite) (默认: mysql)"
  echo "  --db-name NAME            设置数据库名称 (默认: app)"
  echo "  --db-user USER            设置数据库用户 (默认: user)"
  echo "  --db-password PASSWORD    设置数据库密码 (默认: password)"
  echo
}

# 解析命令行参数
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -n|--nomad-addr)
        NOMAD_ADDR="$2"
        shift 2
        ;;
      -c|--consul-addr)
        CONSUL_ADDR="$2"
        shift 2
        ;;
      -d|--domain)
        DOMAIN_NAME="$2"
        shift 2
        ;;
      --cluster)
        CLUSTER_MODE="true"
        shift
        ;;
      --database)
        DATABASE_SERVICE="$2"
        shift 2
        ;;
      --db-name)
        DB_NAME="$2"
        shift 2
        ;;
      --db-user)
        DB_USER="$2"
        shift 2
        ;;
      --db-password)
        DB_PASSWORD="$2"
        shift 2
        ;;
      *)
        echo "未知选项: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# 检查必要的工具是否安装
check_dependencies() {
  echo -e "${YELLOW}检查依赖...${NC}"

  if ! command -v nomad &> /dev/null; then
    echo -e "${RED}错误: Nomad 未安装. 请先安装 Nomad.${NC}"
    echo "安装指南: https://developer.hashicorp.com/nomad/tutorials/get-started/get-started-install"
    exit 1
  fi

  if ! command -v consul &> /dev/null; then
    echo -e "${RED}错误: Consul 未安装. 请先安装 Consul.${NC}"
    echo "安装指南: https://developer.hashicorp.com/consul/tutorials/get-started/get-started-install"
    exit 1
  fi

  if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装. 请先安装 Docker.${NC}"
    echo "安装指南: https://docs.docker.com/engine/install/"
    exit 1
  fi

  echo -e "${GREEN}所有依赖已安装.${NC}"
}

# 构建应用镜像
build_images() {
  echo -e "${YELLOW}构建应用镜像...${NC}"

  # 构建主应用镜像
  echo "构建主应用镜像..."
  docker build -t go-app:latest -f Dockerfile .

  # 构建前端镜像
  echo "构建前端镜像..."
  docker build -t frontend:latest -f frontend/Dockerfile frontend

  # 如果是集群模式，推送镜像到镜像仓库
  if [ "$CLUSTER_MODE" = "true" ]; then
    if [ -z "$DOCKER_REGISTRY" ]; then
      echo -e "${YELLOW}警告: 集群模式下未指定 Docker 镜像仓库地址，将使用本地镜像.${NC}"
      echo -e "${YELLOW}如果 Nomad 客户端无法访问本地镜像，部署可能会失败.${NC}"
    else
      echo "推送镜像到仓库: $DOCKER_REGISTRY"
      docker tag go-app:latest $DOCKER_REGISTRY/go-app:latest
      docker tag frontend:latest $DOCKER_REGISTRY/frontend:latest
      docker push $DOCKER_REGISTRY/go-app:latest
      docker push $DOCKER_REGISTRY/frontend:latest
    fi
  fi

  echo -e "${GREEN}镜像构建完成.${NC}"
}

# 创建必要的卷
create_volumes() {
  if [ "$CLUSTER_MODE" = "true" ]; then
    echo -e "${YELLOW}集群模式下，卷需要在每个 Nomad 客户端上创建.${NC}"
    echo -e "${YELLOW}请确保所有 Nomad 客户端上都有以下卷:${NC}"
    echo "mysql_data, postgres_data, sqlite_data, redis_data, rabbitmq_data, prometheus_data, grafana_data, traefik_logs, app_log_data"
    return
  fi

  echo -e "${YELLOW}创建 Docker 卷...${NC}"

  volumes=(
    "mysql_data"
    "postgres_data"
    "sqlite_data"
    "redis_data"
    "rabbitmq_data"
    "prometheus_data"
    "grafana_data"
    "traefik_logs"
    "app_log_data"
  )

  for volume in "${volumes[@]}"; do
    if ! docker volume inspect "$volume" &> /dev/null; then
      echo "创建卷: $volume"
      docker volume create "$volume"
    else
      echo "卷已存在: $volume"
    fi
  done

  echo -e "${GREEN}卷创建完成.${NC}"
}

# 部署 Nomad 作业
deploy_nomad_jobs() {
  echo -e "${YELLOW}部署 Nomad 作业...${NC}"

  # 设置环境变量
  export NOMAD_ADDR=$NOMAD_ADDR
  export CONSUL_HTTP_ADDR=$CONSUL_ADDR
  export DOMAIN_NAME=$DOMAIN_NAME
  export DATABASE_SERVICE=${DATABASE_SERVICE:-mysql}
  export DB_NAME=${DB_NAME:-app}
  export DB_USER=${DB_USER:-user}
  export DB_PASSWORD=${DB_PASSWORD:-password}
  export DB_PATH=${DB_PATH:-./sqlite_data}
  export REDIS_PASSWORD=${REDIS_PASSWORD:-password}
  export RABBITMQ_USER=${RABBITMQ_USER:-admin}
  export RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-password}
  export GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
  export GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}

  echo "使用以下配置:"
  echo "Nomad 地址: $NOMAD_ADDR"
  echo "Consul 地址: $CONSUL_HTTP_ADDR"
  echo "域名: $DOMAIN_NAME"
  echo "数据库服务: $DATABASE_SERVICE"

  # 部署 Traefik
  echo "部署 Traefik..."
  nomad job run deployments/nomad/traefik.nomad

  # 部署数据库
  echo "部署数据库..."
  nomad job run deployments/nomad/databases.nomad

  # 部署 Redis
  echo "部署 Redis..."
  nomad job run deployments/nomad/redis.nomad

  # 部署 RabbitMQ
  echo "部署 RabbitMQ..."
  nomad job run deployments/nomad/rabbitmq.nomad

  # 部署监控
  echo "部署监控服务..."
  nomad job run deployments/nomad/monitoring.nomad

  # 部署主应用
  echo "部署主应用..."
  nomad job run deployments/nomad/app.nomad

  # 部署前端
  echo "部署前端..."
  nomad job run deployments/nomad/frontend.nomad

  echo -e "${GREEN}所有 Nomad 作业已部署.${NC}"
}

# 检查服务状态
check_services() {
  echo -e "${YELLOW}检查服务状态...${NC}"

  echo "Nomad 作业状态:"
  nomad job status

  echo "Consul 服务状态:"
  consul catalog services

  echo -e "${GREEN}部署完成.${NC}"
  echo -e "${GREEN}请访问 $CONSUL_ADDR 查看 Consul UI.${NC}"
  echo -e "${GREEN}请访问 $NOMAD_ADDR 查看 Nomad UI.${NC}"
  echo -e "${GREEN}应用访问地址: https://$DOMAIN_NAME${NC}"
}

# 主函数
main() {
  parse_args "$@"
  check_dependencies
  build_images
  create_volumes
  deploy_nomad_jobs
  check_services
}

# 执行主函数
main "$@"

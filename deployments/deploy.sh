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
FORCE_BUILD=${FORCE_BUILD:-"false"}
ASYNC_DEPLOY=${ASYNC_DEPLOY:-"false"}
WAIT_TIMEOUT=${WAIT_TIMEOUT:-60}
USE_LOCAL_REGISTRY=${USE_LOCAL_REGISTRY:-"false"}
LOCAL_REGISTRY_ADDR=${LOCAL_REGISTRY_ADDR:-"registry.${DOMAIN_NAME}:5000"}

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
  echo "  --force-build             强制重新构建镜像 (默认: 禁用)"
  echo "  --async                   异步部署模式，不等待服务健康 (默认: 禁用)"
  echo "  --wait-timeout SECONDS    等待服务健康的超时时间 (默认: 60秒)"
  echo "  --use-local-registry      使用本地镜像仓库 (默认: 禁用)"
  echo "  --registry-addr ADDR      设置本地镜像仓库地址 (默认: registry.DOMAIN_NAME:5000)"
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
      --force-build)
        FORCE_BUILD="true"
        shift
        ;;
      --async)
        ASYNC_DEPLOY="true"
        shift
        ;;
      --wait-timeout)
        WAIT_TIMEOUT="$2"
        shift 2
        ;;
      --use-local-registry)
        USE_LOCAL_REGISTRY="true"
        shift
        ;;
      --registry-addr)
        LOCAL_REGISTRY_ADDR="$2"
        shift 2
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

# 检查镜像是否存在
check_image_exists() {
  local image_name=$1
  if docker image inspect "$image_name" &> /dev/null; then
    return 0  # 镜像存在
  else
    return 1  # 镜像不存在
  fi
}

# 构建应用镜像
build_images() {
  echo -e "${YELLOW}检查应用镜像...${NC}"

  local app_image="go-app:latest"
  local frontend_image="frontend:latest"
  local need_build_app=false
  local need_build_frontend=false

  # 检查主应用镜像是否存在
  if check_image_exists "$app_image"; then
    echo "主应用镜像已存在，跳过构建"
  else
    need_build_app=true
  fi

  # 检查前端镜像是否存在
  if check_image_exists "$frontend_image"; then
    echo "前端镜像已存在，跳过构建"
  else
    need_build_frontend=true
  fi

  # 如果需要，构建主应用镜像
  if [ "$need_build_app" = true ] || [ "$FORCE_BUILD" = "true" ]; then
    echo -e "${YELLOW}构建主应用镜像...${NC}"
    docker build -t "$app_image" -f ../Dockerfile ..
  fi

  # 如果需要，构建前端镜像
  if [ "$need_build_frontend" = true ] || [ "$FORCE_BUILD" = "true" ]; then
    echo -e "${YELLOW}构建前端镜像...${NC}"
    docker build -t "$frontend_image" -f ../frontend/Dockerfile ../frontend
  fi

  # 如果使用本地镜像仓库，先设置镜像名称
  if [ "$USE_LOCAL_REGISTRY" = "true" ]; then
    # 设置镜像名称
    export APP_IMAGE="$LOCAL_REGISTRY_ADDR/go-app:latest"
    export FRONTEND_IMAGE="$LOCAL_REGISTRY_ADDR/frontend:latest"

    # 注意：镜像推送将在部署本地镜像仓库后进行
  elif [ "$CLUSTER_MODE" = "true" ]; then
    if [ -z "$DOCKER_REGISTRY" ]; then
      echo -e "${YELLOW}警告: 集群模式下未指定 Docker 镜像仓库地址，将使用本地镜像.${NC}"
      echo -e "${YELLOW}如果 Nomad 客户端无法访问本地镜像，部署可能会失败.${NC}"

      # 使用默认镜像名称
      export APP_IMAGE="go-app:latest"
      export FRONTEND_IMAGE="frontend:latest"
    else
      echo "推送镜像到仓库: $DOCKER_REGISTRY"
      docker tag "$app_image" "$DOCKER_REGISTRY/go-app:latest"
      docker tag "$frontend_image" "$DOCKER_REGISTRY/frontend:latest"
      docker push "$DOCKER_REGISTRY/go-app:latest"
      docker push "$DOCKER_REGISTRY/frontend:latest"

      # 更新镜像名称以在 Nomad 作业中使用
      export APP_IMAGE="$DOCKER_REGISTRY/go-app:latest"
      export FRONTEND_IMAGE="$DOCKER_REGISTRY/frontend:latest"
    fi
  else
    # 使用默认镜像名称
    export APP_IMAGE="go-app:latest"
    export FRONTEND_IMAGE="frontend:latest"
  fi

  echo -e "${GREEN}镜像准备完成.${NC}"
}

# 创建必要的卷
create_volumes() {
  if [ "$CLUSTER_MODE" = "true" ]; then
    echo -e "${YELLOW}集群模式下，需要在每个 Nomad 客户端上创建数据目录.${NC}"
    echo -e "${YELLOW}请确保所有 Nomad 客户端上都有以下目录:${NC}"
    echo "/opt/data/postgres"
    echo "/opt/data/redis"
    echo "/opt/data/rabbitmq"
    echo "/opt/data/prometheus"
    echo "/opt/data/grafana"
    echo "/opt/data/traefik"
    echo "/opt/data/app"
    echo "/opt/data/registry (仅在运行 Registry 的节点上需要)"
    return
  fi

  echo -e "${YELLOW}创建数据目录...${NC}"

  # 不再使用 Docker 卷，而是使用 /opt/data 目录
  # 确保 /opt/data 目录存在
  if ! sudo mkdir -p /opt/data/{postgres,redis,rabbitmq,prometheus,grafana,traefik,app,registry}; then
    echo -e "${RED}错误: 无法创建 /opt/data 目录.${NC}"
    echo "请手动创建以下目录并确保有适当的权限:"
    echo "/opt/data/postgres"
    echo "/opt/data/redis"
    echo "/opt/data/rabbitmq"
    echo "/opt/data/prometheus"
    echo "/opt/data/grafana"
    echo "/opt/data/traefik"
    echo "/opt/data/app"
    echo "/opt/data/registry"
  else
    sudo chmod -R 777 /opt/data
    echo -e "${GREEN}已创建数据目录.${NC}"
  fi

  echo -e "${GREEN}目录创建完成.${NC}"
}

# 部署单个 Nomad 作业
deploy_job() {
  local job_file=$1
  local job_name=$(basename "$job_file" .nomad)

  echo "部署 ${job_name}..."

  if [ "$ASYNC_DEPLOY" = "true" ]; then
    # 异步部署，不等待服务健康
    nomad job run -detach "$job_file"
    echo "已提交作业 ${job_name}，继续部署下一个服务..."
  else
    # 同步部署，等待服务健康
    if ! nomad job run "$job_file"; then
      echo -e "${RED}部署 ${job_name} 失败.${NC}"
      return 1
    fi

    # 等待服务健康
    echo "等待 ${job_name} 服务健康检查通过 (最多 ${WAIT_TIMEOUT} 秒)..."
    local start_time=$(date +%s)
    local current_time=0
    local timeout_seconds=$WAIT_TIMEOUT

    while [ $((current_time - start_time)) -lt $timeout_seconds ]; do
      # 检查作业状态
      if nomad job status "$job_name" | grep -q "running"; then
        echo -e "${GREEN}${job_name} 服务已启动.${NC}"
        return 0
      fi

      echo "等待 ${job_name} 服务启动..."
      sleep 5
      current_time=$(date +%s)
    done

    echo -e "${YELLOW}警告: ${job_name} 服务启动超时，但将继续部署其他服务.${NC}"
  fi
}

# 部署 Nomad 作业
deploy_nomad_jobs() {
  echo -e "${YELLOW}部署 Nomad 作业...${NC}"

  # 设置环境变量
  export NOMAD_ADDR=$NOMAD_ADDR
  export CONSUL_HTTP_ADDR=$CONSUL_ADDR
  export DOMAIN_NAME=$DOMAIN_NAME
  export DATABASE_SERVICE="postgres"  # 固定使用 PostgreSQL
  export DB_NAME=${DB_NAME:-app}
  export DB_USER=${DB_USER:-user}
  export DB_PASSWORD=${DB_PASSWORD:-password}
  export REDIS_PASSWORD=${REDIS_PASSWORD:-password}
  export RABBITMQ_USER=${RABBITMQ_USER:-admin}
  export RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-password}
  export GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
  export GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}

  echo "使用以下配置:"
  echo "Nomad 地址: $NOMAD_ADDR"
  echo "Consul 地址: $CONSUL_HTTP_ADDR"
  echo "域名: $DOMAIN_NAME"
  echo "数据库服务: PostgreSQL"
  echo "异步部署模式: $ASYNC_DEPLOY"

  if [ "$ASYNC_DEPLOY" = "true" ]; then
    echo "服务将在后台部署，不等待健康检查"
  else
    echo "等待服务健康的超时时间: ${WAIT_TIMEOUT}秒"
  fi

  if [ "$USE_LOCAL_REGISTRY" = "true" ]; then
    echo "使用本地镜像仓库: $LOCAL_REGISTRY_ADDR"
    echo "应用镜像: $APP_IMAGE"
    echo "前端镜像: $FRONTEND_IMAGE"
  fi

  # 如果使用本地镜像仓库，先部署 Registry
  if [ "$USE_LOCAL_REGISTRY" = "true" ]; then
    echo "部署本地镜像仓库..."
    deploy_job "nomad/registry.nomad"

    # 等待本地镜像仓库可用
    echo "等待本地镜像仓库可用..."
    local registry_ready=false
    local start_time=$(date +%s)
    local current_time=0
    local timeout_seconds=60

    while [ $((current_time - start_time)) -lt $timeout_seconds ]; do
      if curl -s "http://$LOCAL_REGISTRY_ADDR/v2/" > /dev/null 2>&1; then
        registry_ready=true
        break
      fi
      echo "等待本地镜像仓库启动..."
      sleep 5
      current_time=$(date +%s)
    done

    if [ "$registry_ready" = true ]; then
      echo -e "${GREEN}本地镜像仓库已启动.${NC}"

      # 推送镜像到本地仓库
      echo "推送镜像到本地仓库: $LOCAL_REGISTRY_ADDR"
      docker tag "$app_image" "$LOCAL_REGISTRY_ADDR/go-app:latest"
      docker tag "$frontend_image" "$LOCAL_REGISTRY_ADDR/frontend:latest"
      docker push "$LOCAL_REGISTRY_ADDR/go-app:latest"
      docker push "$LOCAL_REGISTRY_ADDR/frontend:latest"
    else
      echo -e "${YELLOW}警告: 本地镜像仓库启动超时，将使用本地镜像.${NC}"
    fi
  fi

  # 部署 Traefik
  deploy_job "nomad/traefik.nomad"

  # 部署数据库
  deploy_job "nomad/databases.nomad"

  # 部署 Redis
  deploy_job "nomad/redis.nomad"

  # 部署 RabbitMQ
  deploy_job "nomad/rabbitmq.nomad"

  # 部署监控
  deploy_job "nomad/monitoring.nomad"

  # 部署主应用
  deploy_job "nomad/app.nomad"

  # 部署前端
  deploy_job "nomad/frontend.nomad"

  echo -e "${GREEN}所有 Nomad 作业已提交.${NC}"

  if [ "$ASYNC_DEPLOY" = "true" ]; then
    echo -e "${YELLOW}注意: 服务正在后台部署，请使用 Nomad UI 或 'nomad job status' 命令检查部署状态.${NC}"
  fi
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

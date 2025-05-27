# Final DDD 项目 Makefile

.PHONY: help build deploy clean dev prod staging logs status

# 默认目标
help:
	@echo "Final DDD 部署命令:"
	@echo ""
	@echo "构建相关:"
	@echo "  build                构建应用镜像"
	@echo "  build-push          构建并推送到本地仓库"
	@echo ""
	@echo "部署相关:"
	@echo "  dev                 部署到开发环境"
	@echo "  staging             部署到测试环境"
	@echo "  prod                部署到生产环境"
	@echo "  deploy              自定义部署 (需要设置 ENV 变量)"
	@echo ""
	@echo "管理相关:"
	@echo "  status              查看服务状态"
	@echo "  logs                查看应用日志"
	@echo "  clean               清理部署"
	@echo "  clean-all           清理所有内容 (包括数据和镜像)"
	@echo ""
	@echo "示例:"
	@echo "  make dev                    # 部署到开发环境"
	@echo "  make prod DOMAIN=app.com    # 部署到生产环境并指定域名"
	@echo "  make deploy ENV=staging     # 部署到测试环境"

# 变量定义
ENV ?= dev
DOMAIN ?=
FORCE_BUILD ?= false
ASYNC ?= false
CLUSTER_MODE ?= auto

# 构建镜像
build:
	@echo "构建应用镜像..."
	./deploy/scripts/build.sh

# 构建并推送镜像
build-push:
	@echo "构建并推送镜像到本地仓库..."
	./deploy/scripts/build.sh --push --registry localhost:5000

# 开发环境部署
dev:
	@echo "部署到开发环境..."
	./deploy/scripts/deploy.sh --env dev $(if $(DOMAIN),--domain $(DOMAIN)) $(if $(filter true,$(FORCE_BUILD)),--force-build) $(if $(filter true,$(ASYNC)),--async) $(if $(filter-out auto,$(CLUSTER_MODE)),--cluster-mode $(CLUSTER_MODE))

# 测试环境部署
staging:
	@echo "部署到测试环境..."
	./deploy/scripts/deploy.sh --env staging $(if $(DOMAIN),--domain $(DOMAIN)) $(if $(filter true,$(FORCE_BUILD)),--force-build) $(if $(filter true,$(ASYNC)),--async) $(if $(filter-out auto,$(CLUSTER_MODE)),--cluster-mode $(CLUSTER_MODE))

# 生产环境部署
prod:
	@echo "部署到生产环境..."
	@echo "警告: 即将部署到生产环境!"
	@read -p "确认继续? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	./deploy/scripts/deploy.sh --env prod $(if $(DOMAIN),--domain $(DOMAIN)) $(if $(filter true,$(FORCE_BUILD)),--force-build) $(if $(filter true,$(ASYNC)),--async) $(if $(filter-out auto,$(CLUSTER_MODE)),--cluster-mode $(CLUSTER_MODE))

# 自定义部署
deploy:
	@echo "部署到 $(ENV) 环境..."
	./deploy/scripts/deploy.sh --env $(ENV) $(if $(DOMAIN),--domain $(DOMAIN)) $(if $(filter true,$(FORCE_BUILD)),--force-build) $(if $(filter true,$(ASYNC)),--async) $(if $(filter-out auto,$(CLUSTER_MODE)),--cluster-mode $(CLUSTER_MODE))

# 查看服务状态
status:
	@echo "=== Nomad 作业状态 ==="
	nomad job status
	@echo ""
	@echo "=== Consul 服务状态 ==="
	consul catalog services

# 查看应用日志
logs:
	@echo "查看应用日志..."
	@APP_ALLOC=$$(nomad job status app 2>/dev/null | grep -E "running|pending" | head -1 | awk '{print $$1}'); \
	if [ -n "$$APP_ALLOC" ]; then \
		echo "应用分配 ID: $$APP_ALLOC"; \
		nomad alloc logs $$APP_ALLOC app; \
	else \
		echo "未找到运行中的应用实例"; \
	fi

# 清理部署
clean:
	@echo "清理部署..."
	./deploy/scripts/cleanup.sh --env $(ENV)

# 清理所有内容
clean-all:
	@echo "警告: 即将清理所有内容 (包括数据和镜像)!"
	@read -p "确认继续? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	./deploy/scripts/cleanup.sh --env $(ENV) --clean-data --clean-images --force

# 快速重新部署 (强制构建)
redeploy:
	@echo "快速重新部署..."
	make build-push
	make deploy ENV=$(ENV) FORCE_BUILD=true

# 查看部署文档
docs:
	@echo "部署文档位置:"
	@echo "  主文档: deploy/README.md"
	@echo "  环境搭建: deploy/docs/setup.md"
	@echo "  故障排除: deploy/docs/troubleshooting.md"

# 检查环境
check:
	@echo "检查部署环境..."
	@echo "=== 检查必要工具 ==="
	@command -v nomad >/dev/null 2>&1 && echo "✓ Nomad 已安装" || echo "✗ Nomad 未安装"
	@command -v consul >/dev/null 2>&1 && echo "✓ Consul 已安装" || echo "✗ Consul 未安装"
	@command -v docker >/dev/null 2>&1 && echo "✓ Docker 已安装" || echo "✗ Docker 未安装"
	@echo ""
	@echo "=== 检查服务状态 ==="
	@curl -s http://localhost:4646/v1/status/leader >/dev/null 2>&1 && echo "✓ Nomad 服务运行正常" || echo "✗ Nomad 服务未运行"
	@curl -s http://localhost:8500/v1/status/leader >/dev/null 2>&1 && echo "✓ Consul 服务运行正常" || echo "✗ Consul 服务未运行"
	@docker info >/dev/null 2>&1 && echo "✓ Docker 服务运行正常" || echo "✗ Docker 服务未运行"

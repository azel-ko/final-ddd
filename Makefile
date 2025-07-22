# Final DDD Makefile
# 提供便捷的部署和管理命令

.PHONY: help build deploy-local deploy-remote health-check logs clean

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m

# 变量
ENV ?= dev
HOST ?= localhost
DOMAIN ?=
FORCE_BUILD ?= false

help: ## 显示帮助信息
	@echo "$(GREEN)Final DDD 部署工具$(NC)"
	@echo ""
	@echo "$(YELLOW)使用方法:$(NC)"
	@echo "  make <target> [变量=值]"
	@echo ""
	@echo "$(YELLOW)主要目标:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)变量:$(NC)"
	@echo "  $(BLUE)ENV$(NC)          环境 (dev|staging|prod) [默认: dev]"
	@echo "  $(BLUE)HOST$(NC)         远程主机地址"
	@echo "  $(BLUE)DOMAIN$(NC)       应用域名"
	@echo "  $(BLUE)FORCE_BUILD$(NC)  强制重新构建 (true|false) [默认: false]"
	@echo ""
	@echo "$(YELLOW)示例:$(NC)"
	@echo "  make deploy-local ENV=dev"
	@echo "  make deploy-remote HOST=192.168.1.100 ENV=prod"
	@echo "  make health-check ENV=staging"

# 构建相关
build: ## 构建应用
	@echo "$(BLUE)构建应用...$(NC)"
	@if [ -f "./deploy/scripts/build.sh" ]; then \
		./deploy/scripts/build.sh; \
	else \
		echo "$(YELLOW)构建脚本不存在，使用Docker构建...$(NC)"; \
		docker build -t final-ddd:latest .; \
	fi

build-force: ## 强制重新构建应用
	@echo "$(BLUE)强制重新构建应用...$(NC)"
	@FORCE_BUILD=true $(MAKE) build

# 本地部署
deploy-local: ## 本地部署应用
	@echo "$(GREEN)开始本地部署 (环境: $(ENV))...$(NC)"
	@if [ ! -f "./deploy/scripts/k3s-deploy.sh" ]; then \
		echo "$(RED)错误: 部署脚本不存在$(NC)"; \
		exit 1; \
	fi
	@./deploy/scripts/k3s-deploy.sh --env $(ENV) $(if $(filter true,$(FORCE_BUILD)),--force-build) $(if $(DOMAIN),--domain $(DOMAIN))

# 远程部署
deploy-remote: ## 远程部署应用 (需要 HOST 参数)
	@if [ -z "$(HOST)" ]; then \
		echo "$(RED)错误: 必须指定 HOST 参数$(NC)"; \
		echo "$(YELLOW)使用方法: make deploy-remote HOST=192.168.1.100$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)开始远程部署到 $(HOST) (环境: $(ENV))...$(NC)"
	@if [ ! -f "./deploy/scripts/remote-deploy.sh" ]; then \
		echo "$(RED)错误: 远程部署脚本不存在$(NC)"; \
		exit 1; \
	fi
	@./deploy/scripts/remote-deploy.sh --host $(HOST) --env $(ENV) --all $(if $(DOMAIN),--domain $(DOMAIN))

# 环境管理
env-create: ## 创建环境
	@echo "$(BLUE)创建环境: $(ENV)$(NC)"
	@./deploy/scripts/env-manager.sh create --env $(ENV)

env-list: ## 列出所有环境
	@echo "$(BLUE)列出所有环境$(NC)"
	@./deploy/scripts/env-manager.sh list

env-status: ## 查看环境状态
	@echo "$(BLUE)查看环境状态: $(ENV)$(NC)"
	@./deploy/scripts/env-manager.sh status --env $(ENV)

env-destroy: ## 销毁环境
	@echo "$(YELLOW)销毁环境: $(ENV)$(NC)"
	@./deploy/scripts/env-manager.sh destroy --env $(ENV)

# 健康检查和监控
health-check: ## 执行健康检查
	@echo "$(BLUE)执行健康检查 (环境: $(ENV))...$(NC)"
	@./deploy/scripts/health-check.sh --env $(ENV)

health-monitor: ## 持续健康监控
	@echo "$(BLUE)开始持续健康监控 (环境: $(ENV))...$(NC)"
	@./deploy/scripts/health-check.sh --env $(ENV) --continuous --interval 30

# 日志查看
logs: ## 查看应用日志
	@echo "$(BLUE)查看应用日志 (环境: $(ENV))...$(NC)"
	@kubectl logs -f -l app=final-ddd -n final-ddd-$(ENV)

logs-db: ## 查看数据库日志
	@echo "$(BLUE)查看数据库日志 (环境: $(ENV))...$(NC)"
	@kubectl logs -f -l app=postgres -n final-ddd-$(ENV)

logs-all: ## 查看所有日志
	@echo "$(BLUE)查看所有日志 (环境: $(ENV))...$(NC)"
	@kubectl logs -f --all-containers=true -n final-ddd-$(ENV)

# 故障排除
troubleshoot: ## 本地故障排除
	@echo "$(BLUE)执行本地故障排除...$(NC)"
	@./deploy/scripts/remote-troubleshoot.sh diagnose --host localhost --env $(ENV)

troubleshoot-remote: ## 远程故障排除 (需要 HOST 参数)
	@if [ -z "$(HOST)" ]; then \
		echo "$(RED)错误: 必须指定 HOST 参数$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)执行远程故障排除 (主机: $(HOST))...$(NC)"
	@./deploy/scripts/remote-troubleshoot.sh diagnose --host $(HOST) --env $(ENV)

# 版本管理
rollback: ## 回滚到上一版本
	@echo "$(YELLOW)回滚应用 (环境: $(ENV))...$(NC)"
	@./deploy/scripts/rollback.sh --env $(ENV)

# 监控访问
grafana: ## 访问Grafana仪表板
	@echo "$(GREEN)启动Grafana端口转发...$(NC)"
	@echo "$(YELLOW)访问地址: http://localhost:3000$(NC)"
	@echo "$(YELLOW)用户名: admin, 密码: admin123$(NC)"
	@echo "$(YELLOW)按 Ctrl+C 停止$(NC)"
	@kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

prometheus: ## 访问Prometheus
	@echo "$(GREEN)启动Prometheus端口转发...$(NC)"
	@echo "$(YELLOW)访问地址: http://localhost:9090$(NC)"
	@echo "$(YELLOW)按 Ctrl+C 停止$(NC)"
	@kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

app: ## 访问应用
	@echo "$(GREEN)启动应用端口转发...$(NC)"
	@echo "$(YELLOW)访问地址: http://localhost:8080$(NC)"
	@echo "$(YELLOW)按 Ctrl+C 停止$(NC)"
	@kubectl port-forward -n final-ddd-$(ENV) svc/final-ddd-backend-service 8080:8080

# 清理
clean: ## 清理本地资源
	@echo "$(YELLOW)清理本地资源...$(NC)"
	@docker system prune -f
	@docker volume prune -f

clean-env: ## 清理指定环境
	@echo "$(YELLOW)清理环境: $(ENV)$(NC)"
	@./deploy/scripts/env-manager.sh destroy --env $(ENV) --force

# 开发相关
dev-setup: ## 设置开发环境
	@echo "$(BLUE)设置开发环境...$(NC)"
	@./deploy/scripts/install-k3s.sh
	@./deploy/scripts/setup-cluster.sh --env dev

dev-deploy: ## 快速开发部署
	@echo "$(BLUE)快速开发部署...$(NC)"
	@$(MAKE) deploy-local ENV=dev FORCE_BUILD=true

dev-logs: ## 开发环境日志
	@$(MAKE) logs ENV=dev

dev-restart: ## 重启开发环境应用
	@echo "$(BLUE)重启开发环境应用...$(NC)"
	@kubectl rollout restart deployment/final-ddd-app -n final-ddd-dev

# 生产相关
prod-deploy: ## 生产环境部署
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)错误: 生产环境部署需要指定 DOMAIN$(NC)"; \
		echo "$(YELLOW)使用方法: make prod-deploy DOMAIN=your-domain.com$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)生产环境部署...$(NC)"
	@$(MAKE) deploy-local ENV=prod DOMAIN=$(DOMAIN) FORCE_BUILD=true

prod-status: ## 生产环境状态
	@$(MAKE) env-status ENV=prod

prod-logs: ## 生产环境日志
	@$(MAKE) logs ENV=prod

# 状态查看
status: ## 查看集群状态
	@echo "$(BLUE)集群状态:$(NC)"
	@kubectl get nodes
	@echo ""
	@echo "$(BLUE)所有命名空间:$(NC)"
	@kubectl get namespaces
	@echo ""
	@echo "$(BLUE)环境 $(ENV) 状态:$(NC)"
	@kubectl get all -n final-ddd-$(ENV) 2>/dev/null || echo "环境 $(ENV) 不存在"

# 快捷命令
quick-start: ## 快速开始 (安装k3s + 部署dev环境)
	@echo "$(GREEN)快速开始部署...$(NC)"
	@$(MAKE) dev-setup
	@$(MAKE) dev-deploy

# 完整测试
test-deployment: ## 测试部署流程
	@echo "$(BLUE)测试部署流程...$(NC)"
	@$(MAKE) dev-deploy
	@sleep 30
	@$(MAKE) health-check ENV=dev
	@echo "$(GREEN)部署测试完成$(NC)"
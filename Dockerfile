# 多阶段构建

# 阶段 1: 前端构建
FROM docker.1ms.run/node:18-alpine AS frontend-builder
WORKDIR /app/frontend

# 启用 corepack 并安装指定版本的 pnpm
RUN corepack enable && corepack prepare pnpm@10.6.2 --activate

# 复制前端依赖文件
COPY frontend/package.json frontend/pnpm-lock.yaml ./

# 安装依赖
# RUN pnpm config set registry https://repo.huaweicloud.com/repository/npm/ && \
#     pnpm store prune && \
RUN pnpm install --frozen-lockfile

# 复制前端源代码
COPY frontend/ ./

# 构建前端
RUN pnpm run build

# 阶段 2: 后端构建
FROM docker.1ms.run/golang:1.23-alpine AS backend-builder
WORKDIR /app

# 安装基本构建工具
RUN apk add --no-cache git build-base

# 复制 go.mod 和 go.sum
COPY go.mod go.sum ./

# 下载依赖
RUN export GOPROXY=https://goproxy.cn && go mod download

# 复制后端源代码
COPY cmd/ ./cmd/
COPY internal/ ./internal/
COPY pkg/ ./pkg/

# 创建前端构建文件目录
RUN mkdir -p ./internal/interfaces/http/router/frontend/dist/

# 从前端构建阶段复制构建文件
COPY --from=frontend-builder /app/frontend/dist/ ./internal/interfaces/http/router/frontend/dist/

# 获取版本信息
ARG VERSION=dev
ARG BUILD_TIME=unknown
ARG COMMIT_HASH=unknown

# 构建应用
RUN go build -ldflags "-X 'github.com/azel-ko/final-ddd/internal/pkg/version.Version=${VERSION}' -X 'github.com/azel-ko/final-ddd/internal/pkg/version.BuildTime=${BUILD_TIME}' -X 'github.com/azel-ko/final-ddd/internal/pkg/version.CommitHash=${COMMIT_HASH}'" -o final-ddd ./cmd/main.go

# 阶段 3: 最终运行镜像
FROM docker.1ms.run/alpine:latest
WORKDIR /app

# 安装运行时依赖
RUN apk add --no-cache ca-certificates tzdata

# 设置时区
ENV TZ=Asia/Shanghai

# 从构建阶段复制配置文件
COPY configs/ ./configs/

# 从构建阶段复制二进制文件
COPY --from=backend-builder /app/final-ddd .

# 创建日志目录
RUN mkdir -p /app/logs

# 暴露应用端口
EXPOSE 8080

# 设置健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q --spider http://localhost:8080/api/health || exit 1

# 运行应用
CMD ["./final-ddd"]
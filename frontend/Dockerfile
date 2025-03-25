# 构建阶段
FROM docker.1ms.run/node:18-alpine as builder
WORKDIR /app

# 安装 pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

COPY package*.json pnpm*.yaml ./
RUN pnpm install
COPY . .
RUN CI=true pnpm build

# 运行阶段 - 使用 node 静态文件服务器
FROM docker.1ms.run/node:18-alpine
WORKDIR /app

# 安装 bash 并设为默认 shell
RUN apk add --no-cache bash && \
    ln -sf /bin/bash /bin/sh

# 设置 PNPM 环境
ENV PNPM_HOME=/root/.local/share/pnpm
ENV PATH=$PATH:$PNPM_HOME
ENV SHELL=/bin/bash

RUN corepack enable && \
    corepack prepare pnpm@latest --activate && \
    pnpm setup && \
    pnpm add -g serve

COPY --from=builder /app/dist .
EXPOSE 80
CMD ["serve", "-s", ".", "-l", "80"]

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
RUN npm install -g serve
COPY --from=builder /app/dist .
EXPOSE 80
CMD ["serve", "-s", ".", "-l", "80"]

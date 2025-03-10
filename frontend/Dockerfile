# 构建阶段
FROM docker.1ms.run/node:18-alpine as builder
WORKDIR /app

# 安装 pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# 复制 package.json 和 pnpm-lock.yaml (如果存在)
COPY package*.json pnpm*.yaml ./

# 安装依赖
RUN pnpm install

# 复制源代码
COPY . .

# 构建
RUN CI=true pnpm build || (cat /root/.local/share/pnpm/store/v3/log/* && exit 1)

# 运行阶段
FROM docker.1ms.run/nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

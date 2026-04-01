# EchoReading: Node API + Flutter Web（静态文件）
#
# 架构：默认整镜像为 linux/amd64，便于推送到 ECR 后在 ECS/Fargate/常见 EC2（x86_64）上运行。
# 若在 Graviton 上跑，请改用：docker buildx build --platform linux/arm64 ...
#
# 前置：在仓库根目录先构建 Web（API_BASE_URL 填你对外访问的 API 根地址，含协议与端口）
#   flutter build web --release --dart-define=API_BASE_URL=https://your-domain.example
#
# 构建并加载到本机（amd64 镜像，在 Apple Silicon 上会走 QEMU 模拟）：
#   docker buildx build --platform linux/amd64 -t echo-reading:latest --load -f Dockerfile .

# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 node:20-bookworm-slim

WORKDIR /app
ENV NODE_ENV=production

COPY api/package.json api/package-lock.json ./
RUN npm ci --omit=dev

COPY api/ ./

# server.js 中 WEB_BUILD = path.join(__dirname, '..', 'build', 'web') → 对应镜像内 /build/web
COPY build/web /build/web

EXPOSE 3000
CMD ["node", "server.js"]

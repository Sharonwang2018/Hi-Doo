#!/usr/bin/env bash
# 构建 linux/amd64 镜像（与 AWS 上多数 x86_64/Fargate 运行时兼容）。
# 勿在脚本或仓库中写入 AWS AK/SK；登录 ECR 请用 aws configure、IAM Role 或 CI OIDC。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f build/web/index.html ]]; then
  echo "缺少 build/web。请先执行（API_BASE_URL 改为你的公网入口）："
  echo "  flutter build web --release --dart-define=API_BASE_URL=https://your-host"
  exit 1
fi

IMAGE_TAG="${1:-echo-reading:latest}"

docker buildx version >/dev/null 2>&1 || { echo "需要 Docker Buildx"; exit 1; }

# 确保有支持多平台的 builder（Apple Silicon 上构建 amd64 需要）
if ! docker buildx inspect multiarch >/dev/null 2>&1; then
  docker buildx create --name multiarch --driver docker-container --use
else
  docker buildx use multiarch
fi

docker buildx build \
  --platform linux/amd64 \
  -f "$ROOT/Dockerfile" \
  -t "$IMAGE_TAG" \
  --load \
  "$ROOT"

echo "OK: $IMAGE_TAG (linux/amd64)"
echo "推送到 ECR 示例（自行替换账号/区域/仓库名）："
echo "  aws ecr get-login-password --region REGION | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.REGION.amazonaws.com"
echo "  docker tag $IMAGE_TAG ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO:latest"
echo "  docker push ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO:latest"

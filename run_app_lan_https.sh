#!/bin/bash
# Hi-Doo 绘读 - 手机扫码测试（HTTPS，摄像头需安全上下文）
# 手机浏览器需 HTTPS 才能调用摄像头，用 cloudflared 生成 HTTPS 隧道
# 需先安装 cloudflared: brew install cloudflared

cd "$(dirname "$0")"

if ! command -v cloudflared &>/dev/null; then
  echo "❌ 未安装 cloudflared，请先执行: brew install cloudflared"
  exit 1
fi

# 构建 release（AI 配置见 docs/DOUBAO_SETUP.md）
echo "📦 构建中..."
flutter build web \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=API_BASE_URL="${API_BASE_URL:-http://10.0.0.138:3000}"

[ $? -ne 0 ] && exit 1

# 后台启动本地服务器
echo ""
echo "🚀 启动本地服务器 (端口 8082)..."
python3 -m http.server 8082 -b 10.0.0.138 -d build/web &
SERVER_PID=$!
sleep 2

# 启动 cloudflared 隧道（Ctrl+C 退出时会关闭本地服务器）
trap "kill $SERVER_PID 2>/dev/null; exit" INT TERM
echo ""
echo "🔐 启动 Cloudflare HTTPS 隧道..."
echo "📱 手机浏览器打开下方 https 地址，即可调用摄像头扫码"
echo ""
cloudflared tunnel --url http://10.0.0.138:8082

kill $SERVER_PID 2>/dev/null

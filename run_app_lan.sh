#!/bin/bash
# Hi-Doo 绘读 - 局域网手机测试（release 构建，兼容性更好）
# 手机与电脑同一 WiFi，浏览器打开 http://本机IP:8082

cd "$(dirname "$0")"

echo "📱 构建中，完成后手机访问: http://10.0.0.138:8082"
echo ""

# release 构建（AI 配置见 docs/DOUBAO_SETUP.md）
flutter build web \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=API_BASE_URL="${API_BASE_URL:-http://10.0.0.138:3000}"

if [ $? -ne 0 ]; then
  echo "构建失败"
  exit 1
fi

echo ""
echo "✅ 构建完成，启动本地服务器..."
echo "📱 手机浏览器打开: http://10.0.0.138:8082"
echo "按 Ctrl+C 停止"
echo ""

python3 -m http.server 8082 -b 10.0.0.138 -d build/web

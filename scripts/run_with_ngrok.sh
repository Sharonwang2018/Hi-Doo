#!/bin/bash
# 用 ngrok 暴露本地服务，手机访问 ngrok 提供的 HTTPS 地址（无证书警告）
# 1. 安装 ngrok: brew install ngrok 或从 https://ngrok.com 下载
# 2. 本机先启动 API: cd server && HTTPS=1 npm start  或  ./run_all.sh
# 3. 另开终端: ./scripts/run_with_ngrok.sh
# 4. 手机访问 ngrok 输出的 https://xxx.ngrok-free.app

cd "$(dirname "$0")/.."

if ! command -v ngrok &>/dev/null; then
  echo "请先安装 ngrok: brew install ngrok"
  echo "或访问 https://ngrok.com 下载"
  exit 1
fi

echo "确保 API 已在 3000 端口运行（./run_all.sh 或 cd server && HTTPS=1 npm start）"
echo "启动 ngrok..."
echo ""
ngrok http 3000

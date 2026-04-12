#!/bin/bash
# Hi-Doo 绘读：一键启动（UI + API 同源，HTTPS）
# 1. 确保数据库已建: createdb echo_reading && psql -d echo_reading -f sql/schema.sql
# 2. 首次 HTTPS 需生成证书: ./scripts/gen_certs.sh
# 3. 配置 AI: 见 docs/DOUBAO_SETUP.md（豆包 ARK_* 或 OpenRouter + 可选 OpenAI）
# 4. Supabase Auth：export SUPABASE_URL SUPABASE_ANON_KEY，或复制 supabase_flutter.env.example → supabase_flutter.env 并填写；api/.env 配 SUPABASE_JWT_SECRET
# 5. ./run_all.sh
# Browser testing without cert warnings: HTTP=1 ./run_all.sh

cd "$(dirname "$0")"
# shellcheck source=scripts/load_supabase_flutter_env.sh
. ./scripts/load_supabase_flutter_env.sh

PORT="${PORT:-3000}"
# Hint only (Web UI uses same origin — do not bake a fixed API URL unless you export API_BASE_URL_FOR_BUILD).
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
USE_HTTPS=false
[ -f api/certs/cert.pem ] && [ -f api/certs/key.pem ] && [ "${HTTP:-}" != "1" ] && USE_HTTPS=true
SCHEME=http; [ "$USE_HTTPS" = true ] && SCHEME=https

if { [ -z "${ARK_API_KEY:-}" ] || [ -z "${ARK_ENDPOINT_ID:-}" ]; } && [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "⚠️  请配置 LLM：火山方舟（豆包）ARK_API_KEY + ARK_ENDPOINT_ID，或 OpenRouter，详见 docs/DOUBAO_SETUP.md"
  echo ""
fi
if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "⚠️  未配置 OPENAI_API_KEY：TTS/转写将受限（见 docs/DOUBAO_SETUP.md）"
  echo ""
fi

echo "Building Flutter web (same-origin API — open the URL you use below; no fixed LAN IP in the bundle)..."
DONATION_ARGS=()
if [ -n "${DONATION_URL:-}" ]; then
  DONATION_ARGS=(--dart-define=DONATION_URL="$DONATION_URL")
  echo "  DONATION_URL is set (Buy Me a Coffee / Stripe link)."
fi
FLUTTER_DEFINES=()
# Only if you must pin the API host (rare): export API_BASE_URL_FOR_BUILD=https://example.com:3000
if [ -n "${API_BASE_URL_FOR_BUILD:-}" ]; then
  FLUTTER_DEFINES=(--dart-define=API_BASE_URL="${API_BASE_URL_FOR_BUILD}")
  echo "  API_BASE_URL baked in: ${API_BASE_URL_FOR_BUILD}"
fi
SUPABASE_DEFINES=()
if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  SUPABASE_DEFINES=(
    --dart-define=SUPABASE_URL="${SUPABASE_URL}"
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
  )
  echo "  Supabase Auth: SUPABASE_URL + SUPABASE_ANON_KEY passed to Flutter build."
else
  echo "⚠️  未设置 SUPABASE_URL / SUPABASE_ANON_KEY：登录与匿名将不可用，请在 shell export 或 CI 中配置。"
fi
flutter build web \
  "${FLUTTER_DEFINES[@]}" \
  "${SUPABASE_DEFINES[@]}" \
  "${DONATION_ARGS[@]}"

echo ""
if [ "$USE_HTTPS" = true ]; then
  echo "🌐 This machine: ${SCHEME}://localhost:${PORT}  or  ${SCHEME}://127.0.0.1:${PORT}"
  if [ -n "$LAN_IP" ]; then
    echo "🌐 Same Wi‑Fi (this Mac’s IP today): ${SCHEME}://${LAN_IP}:${PORT}"
  fi
  echo "   UI + API same origin. If the browser warns about HTTPS, use Advanced → Proceed, or: HTTP=1 $0"
  echo ""
  cd api && HTTPS=1 npm start
else
  [ -f api/certs/cert.pem ] && [ -f api/certs/key.pem ] || echo "⚠️  For HTTPS first run: ./scripts/gen_certs.sh"
  echo "🌐 This machine: http://localhost:${PORT}  or  http://127.0.0.1:${PORT}"
  if [ -n "$LAN_IP" ]; then
    echo "🌐 Same Wi‑Fi: http://${LAN_IP}:${PORT}"
  fi
  echo ""
  cd api && npm start
fi

#!/usr/bin/env bash
# Vercel: no Flutter on PATH by default — install stable SDK once per build (shallow clone).
# Set in Vercel → Environment Variables: API_BASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY (optional: DONATION_URL).
# API_BASE_URL = site origin only (e.g. https://your-app.vercel.app), NOT .../api — the app already prefixes /api/....
set -eo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter_vercel}"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x "$FLUTTER_ROOT/bin/flutter" ]]; then
    export PATH="$FLUTTER_ROOT/bin:$PATH"
    return 0
  fi
  echo "[vercel] Installing Flutter SDK (stable, shallow clone)…"
  rm -rf "$FLUTTER_ROOT"
  GIT_TERMINAL_PROMPT=0 git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_ROOT"
  export PATH="$FLUTTER_ROOT/bin:$PATH"
  flutter config --no-analytics >/dev/null
  flutter precache --web
}

ensure_flutter
flutter --version

cd "$ROOT"
flutter pub get

DEFINES=()
if [[ -n "${API_BASE_URL:-}" ]]; then
  DEFINES+=(--dart-define="API_BASE_URL=${API_BASE_URL}")
fi
if [[ -n "${SUPABASE_URL:-}" ]]; then
  DEFINES+=(--dart-define="SUPABASE_URL=${SUPABASE_URL}")
fi
if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then
  DEFINES+=(--dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}")
fi
if [[ -n "${DONATION_URL:-}" ]]; then
  DEFINES+=(--dart-define="DONATION_URL=${DONATION_URL}")
fi

if [[ ${#DEFINES[@]} -gt 0 ]]; then
  echo "[vercel] flutter build web with dart-define (API_BASE_URL / Supabase / etc.)"
else
  echo "[vercel] warning: no API_BASE_URL / SUPABASE_* in env — web app may fall back to origin-only API URL"
fi

flutter build web --release "${DEFINES[@]}"

# Source from repo root (after `cd` to Hi-Doo). Loads SUPABASE_* for flutter build --dart-define.
_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_SUPABASE_FLUTTER_ENV="$_REPO_ROOT/supabase_flutter.env"
if [ -f "$_SUPABASE_FLUTTER_ENV" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$_SUPABASE_FLUTTER_ENV"
  set +a
  echo "  Loaded supabase_flutter.env for Flutter (SUPABASE_URL / SUPABASE_ANON_KEY)."
fi
unset _REPO_ROOT _SUPABASE_FLUTTER_ENV

# If both are set, reject obvious template values (avoids signup to https://your_project_ref...).
if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  _su_lc=$(printf '%s' "${SUPABASE_URL}" | tr '[:upper:]' '[:lower:]')
  if printf '%s' "$_su_lc" | grep -qE 'your_project_ref|xxxxxxxx|example\.com'; then
    echo "❌ SUPABASE_URL 仍是示例占位符。请改为 Dashboard → Settings → API 里的 Project URL（形如 https://xxxxx.supabase.co）。"
    exit 1
  fi
  unset _su_lc
  if printf '%s' "${SUPABASE_ANON_KEY}" | grep -q 'replace-with-your-anon-key' || [ "${#SUPABASE_ANON_KEY}" -lt 80 ]; then
    echo "❌ SUPABASE_ANON_KEY 无效或仍是示例。请从同一页复制完整的 anon public key。"
    exit 1
  fi
fi

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not on PATH. Install Flutter in the Vercel build image, or build locally with:"
  echo "  flutter build web --release"
  echo "and deploy the build/web folder (omit buildCommand in vercel.json)."
  exit 1
fi
flutter pub get
flutter build web --release

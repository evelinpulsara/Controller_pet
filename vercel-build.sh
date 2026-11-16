#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.50.0}"
FLUTTER_DIR="${HOME}/flutter-${FLUTTER_VERSION}"

if ! command -v unzip >/dev/null 2>&1; then
  (dnf install -y unzip xz || yum install -y unzip xz) >/dev/null 2>&1 || true
fi

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "Descargando Flutter ${FLUTTER_VERSION}..."
  git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
flutter pub get

DEFINES=()
[ -n "${BACKEND_URL:-}" ] && DEFINES+=("--dart-define=BACKEND_URL=${BACKEND_URL}")
[ -n "${GEMINI_API_KEY:-}" ] && DEFINES+=("--dart-define=GEMINI_API_KEY=${GEMINI_API_KEY}")
[ -n "${SUPABASE_URL:-}" ] && DEFINES+=("--dart-define=SUPABASE_URL=${SUPABASE_URL}")
[ -n "${SUPABASE_KEY:-}" ] && DEFINES+=("--dart-define=SUPABASE_KEY=${SUPABASE_KEY}")

flutter build web --release "${DEFINES[@]+"${DEFINES[@]}"}"
echo "Listo: app compilada en build/web"

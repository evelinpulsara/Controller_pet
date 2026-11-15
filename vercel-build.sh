#!/usr/bin/env bash
# Compila PetTracker (Flutter web) en Vercel.
# Vercel no trae Flutter: este script lo descarga (misma versión que en desarrollo)
# y genera la app en build/web, que es lo que Vercel publica.
#
# Variables de entorno (Vercel → Settings → Environment Variables):
#   GEMINI_API_KEY  (opcional) clave de Gemini para el asistente de IA.
#   SUPABASE_URL / SUPABASE_KEY (opcionales) si no, se usan las del código.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.50.0}"
FLUTTER_DIR="${HOME}/flutter-${FLUTTER_VERSION}"

# Flutter necesita unzip para descargar sus herramientas.
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
[ -n "${GEMINI_API_KEY:-}" ] && DEFINES+=("--dart-define=GEMINI_API_KEY=${GEMINI_API_KEY}")
[ -n "${SUPABASE_URL:-}" ] && DEFINES+=("--dart-define=SUPABASE_URL=${SUPABASE_URL}")
[ -n "${SUPABASE_KEY:-}" ] && DEFINES+=("--dart-define=SUPABASE_KEY=${SUPABASE_KEY}")

flutter build web --release "${DEFINES[@]+"${DEFINES[@]}"}"
echo "Listo: app compilada en build/web"

#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <A|B|C>" >&2
  exit 1
fi

CHOICE="$(echo "$1" | tr '[:lower:]' '[:upper:]')"
case "$CHOICE" in
  A|B|C) ;;
  *)
    echo "Invalid icon choice '$1'. Must be A, B, or C." >&2
    exit 1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MoveX"
BUNDLE_ID="com.linwk.MoveX"
ICNS_SRC="$ROOT_DIR/assets/icns/AppIcon-${CHOICE}.icns"

if [[ -d "/Applications/${APP_NAME}.app" ]]; then
  BUNDLE_DIR="/Applications/${APP_NAME}.app"
elif [[ -d "$ROOT_DIR/dist/${APP_NAME}.app" ]]; then
  BUNDLE_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
else
  echo "Bundle not found; building first..."
  ICON_CHOICE="$CHOICE" "$ROOT_DIR/scripts/build.sh"
  exit 0
fi

WAS_RUNNING=0
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  WAS_RUNNING=1
  pkill -x "$APP_NAME" || true
  sleep 0.5
fi

cp "$ICNS_SRC" "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
touch "$BUNDLE_DIR"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$BUNDLE_DIR"

echo "Switched $BUNDLE_DIR icon to Scheme $CHOICE and re-signed bundle."

if [[ "$WAS_RUNNING" -eq 1 ]]; then
  open "$BUNDLE_DIR"
fi

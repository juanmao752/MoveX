#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MoveX"
BUNDLE_ID="com.linwk.MoveX"
BUNDLE_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_CHOICE="${ICON_CHOICE:-A}"
ICON_UPPER="$(echo "$ICON_CHOICE" | tr '[:lower:]' '[:upper:]')"
ICNS_PATH="$ROOT_DIR/assets/icns/AppIcon-${ICON_UPPER}.icns"

if [[ ! -f "$ICNS_PATH" ]]; then
  echo "Error: Icon file not found at $ICNS_PATH (valid choices: A, B, C)" >&2
  exit 1
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" /tmp/clang-module-cache

TMP_ARM64="/tmp/${APP_NAME}-arm64-$$"
TMP_X86_64="/tmp/${APP_NAME}-x86_64-$$"
trap 'rm -f "$TMP_ARM64" "$TMP_X86_64"' EXIT

COMMON_FLAGS=(
  -O
  -swift-version 5
  -module-cache-path /tmp/clang-module-cache
  -framework Cocoa
  -framework ApplicationServices
  -framework Carbon
  -framework ServiceManagement
)

swiftc "${COMMON_FLAGS[@]}" -target arm64-apple-macosx13.0 "$ROOT_DIR"/Sources/*.swift -o "$TMP_ARM64"
swiftc "${COMMON_FLAGS[@]}" -target x86_64-apple-macosx13.0 "$ROOT_DIR"/Sources/*.swift -o "$TMP_X86_64"

/usr/bin/lipo -create "$TMP_ARM64" "$TMP_X86_64" -output "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ICNS_PATH" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR"/assets/logos/preview-*.png "$RESOURCES_DIR/"

touch "$BUNDLE_DIR"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$BUNDLE_DIR"

echo "Built Universal $BUNDLE_DIR (arm64 + x86_64) with Icon $ICON_UPPER"

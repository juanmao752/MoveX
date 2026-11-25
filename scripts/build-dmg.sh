#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MoveX"
VERSION="${VERSION:-1.0.0}"
ICON_CHOICE="${ICON_CHOICE:-A}"
DMG_NAME="${APP_NAME}-${VERSION}-Universal.dmg"
DMG_PATH="$ROOT_DIR/dist/$DMG_NAME"

ICON_CHOICE="$ICON_CHOICE" "$ROOT_DIR/scripts/build.sh"

STAGING_DIR="/tmp/movex-dmg-staging-$$"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$ROOT_DIR/dist/${APP_NAME}.app" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/安装说明.txt" <<'EOF'
MoveX 安装与使用说明
====================

1. 安装应用
   将 MoveX.app 拖入旁边的 Applications（应用程序）文件夹。

2. 首次打开若提示“Apple 无法验证 MoveX 是否包含恶意软件”
   由于本开源版本采用本地自签名（未购买付费 Apple 公证证书），首次打开可通过以下任一方式放行：
   • 方式一：打开「系统设置 → 隐私与安全性」，拉到底部点击「仍要打开」；
   • 方式二：在终端执行一次：
     xattr -cr /Applications/MoveX.app

3. 授予「辅助功能」权限
   打开 MoveX 后，根据引导窗口在「系统设置 → 隐私与安全性 → 辅助功能」中勾选 MoveX。
   随后即可在 Finder / 桌面直接使用 ⌘X 剪切文件、⌘V 移动文件（重命名与搜索框自动放行文本编辑）。
EOF

rm -f "$DMG_PATH"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

echo "Created Universal DMG: $DMG_PATH"
ls -lh "$DMG_PATH"

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BINDIR="$(swift build -c release --show-bin-path)"
BIN="$BINDIR/Gojo"
APP="build/Gojo.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Gojo"
cp Sources/Gojo/Resources/Info.plist "$APP/Contents/Info.plist"

# 字标等图片资源放入标准位置 Contents/Resources/，由 Bundle.main 加载；codesign 可干净处理。
cp Sources/Gojo/Resources/gojo-wordmark.png "$APP/Contents/Resources/gojo-wordmark.png"

# 应用图标：若缺失则从 SVG 生成
if [ ! -f Sources/Gojo/Resources/Gojo.icns ]; then
  ./Scripts/make-icon.sh
fi
cp Sources/Gojo/Resources/Gojo.icns "$APP/Contents/Resources/Gojo.icns"

# 本地自签名，便于首次右键"打开"运行
codesign --force --deep --sign - "$APP"
echo "已生成 $APP"

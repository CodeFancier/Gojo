#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Gojo"
APP="build/Gojo.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Gojo"
cp Sources/Gojo/Resources/Info.plist "$APP/Contents/Info.plist"

# 本地自签名，便于首次右键"打开"运行
codesign --force --deep --sign - "$APP"
echo "已生成 $APP"

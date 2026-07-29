#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# 全尺寸主图；16/32/64px 使用光学优化的小尺寸源以获得更清晰的剪影
SVG_FULL="Gojo-Logo-Assets/gojo-logo.svg"
SVG_SMALL="Gojo-Logo-Assets/gojo-logo-small.svg"
OUT="Sources/Gojo/Resources/Gojo.icns"
ICONSET="$(mktemp -d)/Gojo.iconset"

command -v rsvg-convert >/dev/null 2>&1 || { echo "需要 rsvg-convert（brew install librsvg）"; exit 1; }
command -v iconutil >/dev/null 2>&1 || { echo "需要 iconutil"; exit 1; }

mkdir -p "$ICONSET"

render() { # render <size> <svg>
  rsvg-convert -w "$1" -h "$1" "$2" -o "$ICONSET/tmp_$1.png"
}

# 小尺寸：光学优化源
for size in 16 32 64; do
  render "$size" "$SVG_SMALL"
done
# 大尺寸：完整主图
for size in 128 256 512 1024; do
  render "$size" "$SVG_FULL"
done

cp "$ICONSET/tmp_16.png"   "$ICONSET/icon_16x16.png"
cp "$ICONSET/tmp_32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/tmp_32.png"   "$ICONSET/icon_32x32.png"
cp "$ICONSET/tmp_64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/tmp_128.png"  "$ICONSET/icon_128x128.png"
cp "$ICONSET/tmp_256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/tmp_256.png"  "$ICONSET/icon_256x256.png"
cp "$ICONSET/tmp_512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/tmp_512.png"  "$ICONSET/icon_512x512.png"
cp "$ICONSET/tmp_1024.png" "$ICONSET/icon_512x512@2x.png"
rm -f "$ICONSET"/tmp_*.png

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$ICONSET"
echo "已生成 $OUT"

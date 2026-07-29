#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SVG="Gojo-Logo-Assets/gojo-logo-concept.svg"
OUT="Sources/Gojo/Resources/Gojo.icns"
ICONSET="$(mktemp -d)/Gojo.iconset"

command -v rsvg-convert >/dev/null 2>&1 || { echo "需要 rsvg-convert（brew install librsvg）"; exit 1; }
command -v iconutil >/dev/null 2>&1 || { echo "需要 iconutil"; exit 1; }

mkdir -p "$ICONSET"
for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$size" -h "$size" "$SVG" -o "$ICONSET/tmp_$size.png"
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

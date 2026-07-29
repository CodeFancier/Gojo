#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/package-app.sh
APP="build/Gojo.app"
DMG="Gojo.dmg"
rm -f "$DMG"

if command -v create-dmg >/dev/null 2>&1; then
  create-dmg --volname "Gojo" --app-drop-link 400 120 \
    --icon "Gojo.app" 120 120 "$DMG" "$APP"
else
  # 回退：用 hdiutil 从含 .app 的目录打 dmg
  STAGE="$(mktemp -d)"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "Gojo" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
  rm -rf "$STAGE"
fi
echo "已生成 $DMG"

#!/usr/bin/env bash
# 启动 Gojo.app 并截屏。需在 macOS（带图形会话）环境运行，配合 seed-demo-data.sh。
# 用法：./Scripts/screenshot-demo.sh [输出目录]
#
# 说明：
#   - 01-shelf.png（展示柜首页）为保底目标，screencapture 通常无需特殊权限即可成功。
#   - 02 / 03 依赖 System Events 模拟键盘，需要辅助功能（TCC）授权，
#     CI runner 可能未授权 → 视为 best-effort，失败不影响保底截图。
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Gojo.app"
OUT="${1:-screenshots}"
mkdir -p "$OUT"

[ -d "$APP" ] || { echo "❌ 找不到 $APP，请先运行 ./Scripts/package-app.sh"; exit 1; }

echo "→ 清除隔离属性（避免 Gatekeeper 拦截非交互启动）"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "→ 启动 Gojo"
open "$APP"

echo "→ 等待窗口就绪"
ready=0
for i in $(seq 1 30); do
  if osascript -e 'tell application "System Events" to (name of every process) as text' 2>/dev/null | grep -q Gojo; then
    ready=1; break
  fi
  sleep 1
done
[ "$ready" = "1" ] || echo "⚠️  未检测到 Gojo 进程，仍尝试截图"
sleep 4   # 额外等待 SwiftUI 首屏渲染

echo "→ 调整窗口大小/位置（best-effort，隐藏标题栏 app 可能不受控）"
osascript <<'OSA' 2>/dev/null || true
tell application "System Events"
  tell process "Gojo"
    set frontmost to true
    try
      set position of window 1 to {0, 25}
      set size of window 1 to {1440, 900}
    end try
  end tell
end tell
OSA
sleep 2

echo "→ 截图 1/3：展示柜（保底）"
if screencapture -x -o "$OUT/01-shelf.png"; then echo "  ✓ 01-shelf.png"; else echo "  ✗ 展示柜截图失败"; fi

echo "→ best-effort：按 Return 进入焦点编码空间"
osascript -e 'tell application "System Events" to keystroke (ASCII character 36)' 2>/dev/null || true
sleep 3
screencapture -x -o "$OUT/02-coding-space.png" 2>/dev/null && echo "  ✓ 02-coding-space.png" || echo "  ⚠ 编码空间截图失败/可能仍为展示柜"

echo "→ best-effort：返回展示柜，进入公共空间（轮播首位）"
osascript -e 'tell application "System Events" to key code 53' 2>/dev/null || true   # Esc 返回
sleep 1
osascript -e 'tell application "System Events" to key code 123' 2>/dev/null || true  # ← 到首位
sleep 1
osascript -e 'tell application "System Events" to keystroke (ASCII character 36)' 2>/dev/null || true
sleep 3
screencapture -x -o "$OUT/03-public-space.png" 2>/dev/null && echo "  ✓ 03-public-space.png" || echo "  ⚠ 公共空间截图失败"

echo "→ 完成，截图目录：$OUT"
ls -la "$OUT" 2>/dev/null || true

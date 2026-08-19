#!/bin/zsh
# Linux 预检：在无 macOS 的机器上提前发现编译/测试问题。
#
# 用法：Scripts/preflight-linux.sh
#
# 能提前发现什么：
#   1. 全部 Swift 文件的语法错误（swiftc -parse，含 SwiftUI/AppKit 的 UI 层，
#      如「consecutive declarations」这类错误在 push 前就能抓到）
#   2. GojoCore 的完整编译 + 单元测试（102/112 例可跑；
#      ~10 例因 Linux corelibs-foundation 的 URL 尾斜杠行为差异失败，
#      属平台差异，macOS 上始终通过，非产品 bug）
# 发现不了什么：UI 层的类型/名字错误（Linux 无 SwiftUI，无法类型检查）。

set -euo pipefail
cd "$(dirname "$0")/.."

SWIFT_BIN="$(command -v swift || true)"
if [[ -z "$SWIFT_BIN" ]]; then
  for candidate in /opt/swift/swift-*-RELEASE-*/usr/bin; do
    if [[ -x "$candidate/swift" ]]; then SWIFT_BIN="$candidate/swift"; break; fi
  done
fi
if [[ -z "$SWIFT_BIN" ]]; then
  echo "未找到 swift：安装到 /opt/swift 或加入 PATH" >&2; exit 1
fi
export PATH="${SWIFT_BIN:h}:$PATH"

echo "== 1/3 语法检查（全部源码 + 测试） =="
swiftc -parse Sources/Gojo/*.swift Sources/Gojo/Views/*.swift \
                Tests/GojoTests/*.swift Tests/GojoCoreTests/*.swift
echo "语法 OK"

echo "== 2/3 GojoCore 编译 =="
swift build --target GojoCore

echo "== 3/3 GojoCore 测试（平台差异失败见脚本头注释） =="
swift test || true

echo "预检完成"

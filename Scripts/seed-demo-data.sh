#!/usr/bin/env bash
# 为 Gojo 截图预置演示数据：1 个公共空间 + 3 个编码空间。
# 幂等：每次运行整体重建 $HOME/GojoDemo 与中央索引。
# 目录名用英文（规避路径问题），界面显示名用中文（写入清单 name 字段）。
#
# 数据流依据（见 Sources/GojoCore/WorkspaceManager.swift）：
#   - AppState.reload() 读 index.json → 直达主界面，无需文件选择器交互。
#   - publicProjects() 会扫描公共空间含 .git 的子目录并补录；手写 public.json
#     后因同名去重而保留固定 UUID，确保软链接成员的 publicProjectId 一致。
#   - scanMembers() 靠「有 .git 的文件夹」识别 git 成员、靠「符号链接 + 清单绑定」
#     识别软链接成员。
set -euo pipefail

DEMO_ROOT="${HOME}/GojoDemo"
PUB="${DEMO_ROOT}/PublicSpace"
SPACES="${DEMO_ROOT}/spaces"
INDEX_DIR="${HOME}/Library/Application Support/Gojo"

rm -rf "$DEMO_ROOT"
mkdir -p "$PUB" "$SPACES" "$INDEX_DIR"

# 公共项目的固定 UUID：本进程内生成，保证 public.json 与各 workspace.json 引用一致。
U_ORDER_API=$(uuidgen | tr 'A-Z' 'a-z')
U_ORDER_WORKER=$(uuidgen | tr 'A-Z' 'a-z')
U_MARKETING=$(uuidgen | tr 'A-Z' 'a-z')
U_SHARED_UI=$(uuidgen | tr 'A-Z' 'a-z')

# 造一个本地 git 仓库：init(main) + README + 首次提交 + origin remote。
make_repo() {
  local path="$1" name="$2"
  rm -rf "$path"; mkdir -p "$path"
  git -C "$path" -c init.defaultBranch=main init -q
  printf '# %s\n\nGojo 截图演示用的本地仓库（%s）。\n' "$name" "$name" > "$path/README.md"
  git -C "$path" add -A
  GIT_AUTHOR_NAME="Gojo Demo" GIT_AUTHOR_EMAIL="demo@gojo.app" \
  GIT_COMMITTER_NAME="Gojo Demo" GIT_COMMITTER_EMAIL="demo@gojo.app" \
    git -C "$path" commit -qm "initial commit"
  git -C "$path" remote add origin "https://github.com/CodeFancier/${name}.git"
}

echo "→ 在公共空间造 4 个仓库"
make_repo "$PUB/order-api"         order-api
make_repo "$PUB/order-worker"      order-worker
make_repo "$PUB/marketing-service" marketing-service
make_repo "$PUB/shared-ui-kit"     shared-ui-kit

# 手写 public.json（固定 UUID；扫描时同名去重，不会被覆盖）。
mkdir -p "$PUB/.gojo"
cat > "$PUB/.gojo/public.json" <<EOF
{
  "projects": [
    {"id":"$U_ORDER_API","name":"order-api","url":"https://github.com/CodeFancier/order-api.git","cloned":true,"relativePath":null},
    {"id":"$U_ORDER_WORKER","name":"order-worker","url":"https://github.com/CodeFancier/order-worker.git","cloned":true,"relativePath":null},
    {"id":"$U_MARKETING","name":"marketing-service","url":"https://github.com/CodeFancier/marketing-service.git","cloned":true,"relativePath":null},
    {"id":"$U_SHARED_UI","name":"shared-ui-kit","url":"https://github.com/CodeFancier/shared-ui-kit.git","cloned":true,"relativePath":null}
  ]
}
EOF

# 写编码空间清单：name 用中文（界面展示），members 引用一致的 UUID。
write_workspace() {
  local space_dir="$1" display_name="$2" members_json="$3"
  mkdir -p "$space_dir/.gojo"
  cat > "$space_dir/.gojo/workspace.json" <<EOF
{
  "name": "$display_name",
  "members": $members_json
}
EOF
}

echo "→ 造编码空间：电商中台"
EC="$SPACES/ecommerce"
make_repo "$EC/order-api" order-api                   # git 成员（独立副本）
ln -s "$PUB/shared-ui-kit" "$EC/shared-ui-kit"         # 软链接成员
write_workspace "$EC" "电商中台" "[
  {\"id\":\"$(uuidgen | tr 'A-Z' 'a-z')\",\"folderName\":\"order-api\",\"publicProjectId\":\"$U_ORDER_API\",\"mode\":\"git\"},
  {\"id\":\"$(uuidgen | tr 'A-Z' 'a-z')\",\"folderName\":\"shared-ui-kit\",\"publicProjectId\":\"$U_SHARED_UI\",\"mode\":\"symlink\"}
]"

echo "→ 造编码空间：风控系统"
RK="$SPACES/risk"
make_repo "$RK/marketing-service" marketing-service    # git 成员
write_workspace "$RK" "风控系统" "[
  {\"id\":\"$(uuidgen | tr 'A-Z' 'a-z')\",\"folderName\":\"marketing-service\",\"publicProjectId\":\"$U_MARKETING\",\"mode\":\"git\"}
]"

echo "→ 造编码空间：实验台"
LB="$SPACES/lab"
mkdir -p "$LB"                                          # 该空间仅含软链接成员，需先建目录
ln -s "$PUB/order-worker" "$LB/order-worker"           # 软链接成员
write_workspace "$LB" "实验台" "[
  {\"id\":\"$(uuidgen | tr 'A-Z' 'a-z')\",\"folderName\":\"order-worker\",\"publicProjectId\":\"$U_ORDER_WORKER\",\"mode\":\"symlink\"}
]"

echo "→ 写中央索引"
cat > "$INDEX_DIR/index.json" <<EOF
{
  "publicSpacePath": "$PUB",
  "codingSpacePaths": ["$EC", "$RK", "$LB"],
  "terminalPreference": "terminal"
}
EOF

echo "✓ 演示数据已就绪"
echo "  公共空间：$PUB"
echo "  编码空间：$EC / $RK / $LB"
echo "  索引：    $INDEX_DIR/index.json"

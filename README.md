<p align="center">
  <img src="./BrandAssets/exports/logo/color/gojo-logo-512.png" alt="Gojo Logo" width="180">
</p>

<h1 align="center">Gojo</h1>

<p align="center">
  <strong>把散落的仓库，展开成你的 AI 编码领域。</strong>
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/macOS-13.0%2B-111827?style=flat-square&logo=apple&logoColor=white">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-3B82F6?style=flat-square&logo=swift&logoColor=white">
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-60A5FA?style=flat-square">
  <img alt="Version" src="https://img.shields.io/badge/version-0.1.7-374151?style=flat-square">
  <img alt="License" src="https://img.shields.io/badge/license-Apache--2.0-8B5CF6?style=flat-square">
</p>

> [!NOTE]
> Gojo 处于 `0.1.x` 早期开发阶段：核心工作流已经可用，但界面、清单结构与分发方式仍会演进。建议先在可恢复的仓库与目录中体验，并照常保持 Git 提交与重要文件备份。

Gojo 是一款原生 macOS AI 编码空间管理器。它把公共仓库、独立工作区、Git 分支，以及 Claude Code / Codex 留下的项目记忆与历史会话，收进一个可视化的桌面应用里。

你可以把常用仓库集中放进「公共空间」，再通过 **Git 克隆**或**软链接**投放到不同的「编码空间」中。每个编码空间都是一套独立的开发上下文：需要隔离时就 clone，需要共享时就 link，不必再手动复制目录、寻找路径或记住每个终端窗口属于哪里。

## 🌀 「领域展开」

在五条悟老师的领域里，无限的信息会涌入意识；在 Gojo 的领域里，散落在文件夹、仓库、分支和 AI 会话中的上下文，会被收束成一个清晰、可操作的空间。

首页是一座编码空间展示柜。选中一个空间，卡片便向窗口铺开，成员仓库从中浮现——这不是炫技式的皮肤，而是让每一次进入项目，都像真正切换到一片完整的工作领域。

> Gojo 是一个献给开发者与五条悟粉丝的非官方致敬项目，与《咒术回战》及其权利方不存在隶属或授权关系。

## ✨ 功能特性

### 🏯 展示柜

- **焦点轮播**浏览多个编码空间，键盘方向键、触控板横向滚动切换
- 深色「领域」视觉、焦点呼吸动画与展开转场
- 尊重 macOS「减弱动态效果」与辅助功能字体设置

### 🌐 公共空间

- 指定一个文件夹作为共享仓库池，登记 Git 地址、按需 Clone
- 自动发现已有 Git 仓库，复合文件夹中的子仓库可提升为独立项目
- 关键字搜索公共项目，查看已克隆 / 待同步状态
- 被编码空间引用的项目受删除保护

### 🌀 编码空间

- 指定根目录后，新建空间只需填名称（重名自动 `_2`、`_3`）
- 组合公共项目与独立 Git 仓库，成员卡片实时显示分支与来源形态
- 从公共项目栏拖拽投放，双落区直接选择加入方式
- Clone、同步、模式切换在后台串行执行，并显示进行中状态
- 一键打开 Finder 或 Terminal / iTerm2 / Warp / Otty，长按可固定偏好终端

### 🔀 Git 与软链接，双模式自由切换

| 模式 | 适合场景 | 行为 |
| --- | --- | --- |
| **Git 克隆** | 需要独立分支、独立修改、并行开发 | 在编码空间内创建独立仓库副本 |
| **软链接** | 只需共享同一份代码、节省磁盘空间 | 指向公共空间中的仓库，不重复存储 |

已加入的公共项目可以在两种模式之间切换。Git 模式支持拉取同步与分支切换；切回软链接前，Gojo 会检查未提交和未推送的改动并给出警告。

### 🧠 找回 AI 助手的记忆

- 读取当前项目的 Claude Code `memory/*.md`
- 汇总 Claude Code 与 Codex 历史会话，按项目路径匹配（兼容软链接的真实路径）
- 点击会话，在偏好终端中直接执行 `claude --resume` 或 `codex resume`
- 只读本机已有的助手数据，未使用过的助手显示清晰的空状态

### 🛡️ 对删除保持克制

- 删除公共项目前先检查引用；移除空间可选只取消登记或移入废纸篓
- 对根目录、用户主目录和未登记路径设置破坏性操作保护
- 清理软链接成员不会删除公共仓库本体
- 清单原子写入、工作区操作串行执行，避免并发覆盖

## ⚙️ 它是怎样工作的？

```mermaid
flowchart LR
    P[公共空间<br/>共享仓库池]
    P -->|软链接 · 共享代码| A[编码空间 A]
    P -->|Git Clone · 独立开发| B[编码空间 B]
    P -->|按需组合| C[编码空间 C]
    A --> M[Claude / Codex<br/>项目记忆与会话]
    B --> M
    C --> M
```

Gojo 不会接管你的 Git 仓库，也不要求特殊的工程格式。它只在所选目录中维护轻量的 `.gojo` 清单，并在用户应用支持目录中保存中央索引：

```text
~/Library/Application Support/Gojo/index.json
公共空间/.gojo/public.json
编码空间/.gojo/workspace.json
```

仓库依然是普通文件夹，可以继续被 Git、IDE、终端和其他工具直接使用。

## 📦 安装

### 方式一：下载 DMG（无需开发环境）

1. 从 [Releases](https://github.com/CodeFancier/Gojo/releases) 下载最新的 `Gojo-x.x.x.dmg`。
2. 打开镜像，把 Gojo 拖入「应用程序」文件夹。
3. 首次打开如遇「无法验证开发者」提示，参见 [FAQ](#-faq)。

### 方式二：用脚本本地打包

需要 macOS 13+、Xcode（含命令行工具）与 Git：

```bash
git clone https://github.com/CodeFancier/Gojo.git
cd Gojo
./Scripts/package-app.sh
open build/Gojo.app
```

脚本会执行 Release 构建、组装 `Gojo.app` 并进行本地 ad-hoc 签名。开发调试可用 `swift run` 直接从源码启动，`swift test` 运行测试；需要分发镜像时用 `./Scripts/make-dmg.sh` 生成 DMG。

## 🧭 快速上手

1. 打开底部的「公共空间」，指定一个用于集中保存共享仓库的文件夹。
2. 添加仓库名称与 Git URL，并在需要时点击 Clone。
3. 返回展示柜，通过末尾的 `+` 卡片创建一个编码空间。
4. 进入编码空间，搜索并拖起公共项目。
5. 投放到「Git 克隆」或「软链接」区域，完成领域编排。
6. 在成员卡片上同步、切换分支、转换模式，或打开 Claude / Codex 历史会话。

## 📋 常用操作

| 想做什么 | 在 Gojo 中怎么做 |
| --- | --- |
| 为新任务准备一组仓库 | 新建编码空间，从公共项目栏拖入所需项目 |
| 同一仓库同时开发多个分支 | 分别以 Git 模式加入不同编码空间 |
| 多个空间共享一份只读或同步代码 | 以软链接模式加入 |
| 拉取远端更新 | 悬停 Git 成员卡片，点击同步 |
| 切换分支 | 悬停 Git 成员卡片，打开分支选择器 |
| 恢复 AI 编码现场 | 点击成员卡片或领域顶栏中的 Claude / Codex 按钮 |
| 直接进入命令行或文件目录 | 使用领域顶栏的终端 / Finder 按钮 |
| 移除一个编码空间 | 拖动空间卡片到垃圾桶图标，选择只取消登记或移入废纸篓 |

## ❓ FAQ

**打开时提示「无法验证开发者」怎么办？**

Gojo 目前只做本地 ad-hoc 签名，未经 Apple 公证，首次打开会被 Gatekeeper 拦截。在 Finder 中右键 Gojo 选择「打开」，或到「系统设置 → 隐私与安全性」点击「仍要打开」，之后即可正常启动。

**Git 克隆和软链接怎么选？**

同一仓库要多分支并行开发，选 Git 克隆；多个空间只读共享同一份代码、节省磁盘，选软链接。两种模式加入后可以随时互切，切回软链接前 Gojo 会检查未提交、未推送的改动并给出警告。

**我的数据存在哪里？Gojo 会动我的仓库吗？**

Gojo 只维护轻量的 `.gojo` 清单和一份中央索引（`~/Library/Application Support/Gojo/index.json`）。仓库始终是普通文件夹，可以继续被 Git、IDE 和终端直接使用；删除 Gojo 应用不会影响任何仓库数据。

**没用过 Claude Code / Codex，能用 Gojo 吗？**

能。AI 会话是只读的增强能力：本机没有对应助手的数据时，会显示清晰的空状态，其余功能不受影响。

**支持 Windows / Linux 吗？**

目前仅支持 macOS 13+，暂无其他平台的计划。

## 🗺️ Roadmap

- [x] 公共空间与编码空间管理
- [x] Git 克隆 / 软链接双模式与互转
- [x] Claude Code / Codex 会话恢复
- [x] 扫描根目录下已有项目，原位登记为编码空间
- [ ] Homebrew cask 安装
- [ ] Developer ID 签名与公证
- [ ] 英文界面与双语 README
- [ ] 支持更多 AI 编码助手

## 🤝 参与贡献

欢迎通过 [issue](https://github.com/CodeFancier/Gojo/issues) 提出建议、报告问题，或直接提交 PR；历史设计文档（spec 与 plan）见 [`docs/superpowers/`](./docs/superpowers)，可以了解每个特性的演进脉络。

如果你也想拥有一片更清晰的编码领域，欢迎试用、提出建议，或一起完善它。

## 📄 License

[Apache-2.0](./LICENSE)

Copyright 2026 Fancy Jiang

# Gojo 展示柜交互界面 设计文档

> 日期：2026-07-30
> 状态：已确认，待写实现计划
> 关系：领域模型沿用 `2026-07-29-gojo-flatten-and-modes-design.md`（两层结构、三种成员形态、模式可来回切）。本文档只改**交互界面**，不改领域模型与 `WorkspaceManager` 的既有语义。

## 一、背景与目标

当前界面是 `NavigationSplitView` + 侧边栏树 + 详情列表。四条诉求指向同一个方向——把「文件管理器」气质的界面换成有空间感、有动画、靠图标说话的界面：

1. 更强的动画效果。
2. 用图标区分仓库来源：软链接 / Git 克隆 / 公共空间里未加入的项目。
3. 首页不再是侧边栏，而像**商品展示柜**：滑动找到目标编码空间，然后进入。
4. 编码空间内可以**拖入**公共空间的项目。

结构性后果：侧边栏消失，导航从「同屏两栏」变成「单窗口逐层进入」。这带来两个必须重新安排的既有能力——公共空间的管理入口、成员在编码空间之间的移动——本文档都给出了归宿。

## 二、九个已确认决策

| # | 决策点 | 取值 |
|---|--------|------|
| 1 | 来源图标语言 | **统一底图 + 来源角标**：所有成员共用 `shippingbox` 底图，右下角圆形角标回答「它怎么来的」 |
| 2 | 展示柜形态 | **焦点轮播**：居中卡片放大发光，两侧缩小去饱和 |
| 3 | 卡片信息量 | **成员缩略墙**：卡片内直接铺出成员图标 + 名字，超出收成 `+N` |
| 4 | 进入转场 | **领域展开**：焦点卡片原地放大铺满窗口，成员网格从卡片内部长出 |
| 5 | 拖入模式选择 | **双落区**：拖起托盘胶囊即浮出「Git 克隆 / 软链接」两个落区，落哪边即哪个模式，零弹窗 |
| 6 | 跨空间移动 | **拖回展示柜投放**：拖成员卡片往上，领域收回展示柜，其余空间卡变落区 |
| 7 | 公共空间入口 | **轮播首位一张固定卡**，进入后同样领域展开，内含指定文件夹 / 新增项目 / Clone |
| 8 | 成员操作触达 | **悬停浮出操作条 + 右键菜单** |
| 9 | 焦点卡呼吸浮动 | **保留**（3.6s 循环，幅度 4pt；减弱动态效果时静止） |

### 两条设计假设

用户未就以下两点表态，按下列取值推进；如需调整请指出。

- **异步克隆纳入范围。** `AppState.run` 目前在 `@MainActor` 上同步执行，一次 `git clone` 会锁住主线程数十秒。在当前列表 UI 下勉强可忍，但双落区动画播完就卡死会让动画变成假的。因此新增异步执行路径，属于本次范围。
- **`GojoCore` 下沉只做四项。** 仅下沉新 UI 真正需要的纯逻辑（见第六节），不顺手重构其他既有代码。

## 三、信息架构与导航

`NavigationSplitView` 与 `SidebarSelection` 整体移除，换成单窗口路由：

```
Route
├── .shelf                                     展示柜（首页，焦点轮播）
├── .publicSpace                               公共空间领域
├── .codingSpace(URL)                          编码空间领域
└── .shelfDropping(source: URL, folder: String) 投放模式：展示柜叠在源领域之上
```

同时只呈现一个 Route，`ZStack` + `matchedGeometryEffect` 承载领域展开。`.shelfDropping` 是第 5.4 节跨空间移动的中间态——它必须是一个 Route 而非独立布尔标志，因为源领域需要留在视图层级内（见 5.4 的拖拽约束）。

**轮播队列** = 公共空间卡（固定首位，不参与排序） + N 个编码空间卡 + 末位「新建编码空间」卡。后两者的顺序即 `CentralIndex.codingSpacePaths` 的顺序，本次不引入自定义排序。

「新建编码空间」卡也是一张真卡片（虚线描边 + `plus` 图标），点击走现有 `createCodingSpace()` 的选择文件夹面板。这是设计推导，非用户显式确认。

**焦点判定**用原生滚动驱动，双轨输入互不干扰：

- 双指横滑 / 触控板惯性：`ScrollView(.horizontal)` 原生滚动。每张卡用 `GeometryReader` 上报中心点，离视口中心最近者为焦点。
- `←` `→` 键：改焦点索引，再由 `ScrollViewReader` 滚动到居中。

**返回展示柜**三条路径等价：左上角返回按钮、`⌘[`、`Esc`。例外：处于 `.shelfDropping` 时 `Esc` 归系统的拖拽取消，此时松手回到原领域，不返回展示柜。

**能力归宿**（原侧边栏 / 详情区能力去哪了）：

| 原能力 | 新归宿 |
|--------|--------|
| 指定公共空间文件夹 | 公共空间领域内 |
| 新增公共项目定义 / Clone | 公共空间领域内 |
| 新建编码空间 | 展示柜轮播末位一张「+」卡 |
| 公共项目拖入编码空间 | 编码空间领域底部托盘 → 双落区 |
| 成员跨空间移动 | 拖成员卡片往上 → 展示柜投放模式 |
| 成员同步 / 切分支 / 转模式 | 成员卡片悬停操作条 + 右键菜单 |
| 终端 / 访达 | 两个领域的顶栏（作用于当前领域的文件夹）。展示柜不显示这两个按钮——那里没有「当前文件夹」 |

**公共空间未指定时**，`.publicSpace` 领域内显示单个「指定公共空间文件夹」的空态引导；此时托盘为空，双落区整体不可用。

## 四、视觉语言

### 4.1 来源角标

单一组件 `SourceBadgeIcon(kind:size:)` 集中决定渲染，展示柜缩略墙、成员网格、拖拽芯片、底部托盘四处共用，尺寸参数化。

`kind` 不直接用 `MemberForm`，因为托盘里的公共项目**还不是成员**（无 `MemberForm` 可言）。下沉到 `GojoCore` 的映射表以一个四值枚举为输入：

| kind | 底图 | 角标 | 角标底色 |
|------|------|------|---------|
| `.standalone`（对应 `MemberForm.standalone`） | `shippingbox` | 无 | — |
| `.publicGit`（对应 `MemberForm.publicGit`） | `shippingbox` | `arrow.triangle.branch` | Core Blue `#3B82F6` |
| `.publicSymlink`（对应 `MemberForm.publicSymlink`） | `shippingbox` | `link` | Light Blue `#60A5FA` |
| `.unjoinedPublic`（托盘内的公共项目） | `globe` | 无 | Light Blue 描边 |

映射表同时提供 `MemberForm → kind` 的转换，调用方不重复判断。

形态切换时**只有角标交叉淡入，底图不动**——这是选定该方案的核心收益，模式来回切时卡片不跳。

角标外圈描边取所在容器的背景同色，保证在任意卡片材质上都能切出边界。

### 4.2 卡片

- **焦点卡**：空间名、仓库数、成员缩略墙（`SourceBadgeIcon` + 文件夹名的小胶囊，宽度超出收成 `+N`）。Light Blue 描边、蓝色外发光、呼吸浮动。
- **侧卡**：缩放 0.9、不透明度 0.42、去饱和，仅留空间名。
- **成员卡**（编码空间内）：`SourceBadgeIcon`、文件夹名、实时分支名。悬停时底部滑出操作条。

### 4.3 配色

只用既有品牌四色，不引入新色：Core Blue `#3B82F6`、Light Blue `#60A5FA`、Deep Ink `#111827`、Slate `#374151`。深色渐变底 `#0C1424 → #16213A`。

## 五、动画与拖放

### 5.1 Motion 常量集

所有时长与曲线集中在一处，`accessibilityReduceMotion` 打开时整体退化为交叉淡入：

| 动作 | 参数 |
|------|------|
| 领域展开 / 收回 | `.spring(response: 0.42, dampingFraction: 0.82)` |
| 成员网格错峰浮现 | 每张卡 0.08s 步进 |
| 焦点卡呼吸浮动 | 3.6s 循环，位移 4pt，缩放 1.008 |
| 落区出现 / 消失 | 0.18s 淡入淡出 |
| 角标形态切换 | 0.2s 交叉淡入 |

### 5.2 领域展开

`matchedGeometryEffect` 把焦点卡片与领域标题栏绑成同一几何 ID。展开时：焦点卡放大铺满 → 侧卡下沉淡出 → 成员网格从卡片内部错峰浮现。返回时同一套反播。

### 5.3 双落区拖放

按住托盘胶囊 → 成员网格降到 0.35 不透明度 → 上方浮出两个落区：

- **Git 克隆**：独立 `.git`，可单独切分支改代码。
- **软链接**：指向公共空间，引用不占空间。公共项目 `cloned == false` 时**置灰不可放**——把 `WorkspaceError.publicProjectNotCloned` 从运行时错误前移为视觉状态。

落区各自是一个 `onDrop`，落在哪个区域即决定 `MemberMode`，不再出现 `confirmationDialog`。

**已知的 SwiftUI 约束**：`onDrag` 闭包在拖拽开始时被调用（可借它点亮落区），但**没有对应的拖拽结束回调**。落在落区上由 `onDrop` 清理；落在窗外或按 `Esc` 取消则会留下悬空落区。解决办法是拖拽期间挂 `NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp)`，松手即清理，结束后移除监听。这是本设计**唯一**需要下探到 AppKit 的地方。

### 5.4 跨空间移动（投放模式）

拖起成员卡片往上 → 领域视觉收回成展示柜 → 其余空间卡变虚线落区 → 松手落入。

**关键约束**：拖拽会话由发起它的 NSView 持有，**源视图不能从层级中移除**，否则拖拽被系统取消。所以「收回」是纯视觉的：空间领域保留在视图层级内做缩放淡出，展示柜叠加其上。源空间卡片不亮落区（沿用现有 `draggingFromSpace` 抑制逻辑）。

### 5.5 异步执行与进行中态

新增 `AppState.runAsync`，把 `WorkspaceManager` 调用送到 detached task；同步 `run` 保留给瞬时操作。

落位反馈：成员卡片**先以「进行中」形态落位**（角标位置替换为进度指示器），完成后交叉淡入为正式角标。进行中的卡片不接受操作。

进行中集合以「空间路径 + 文件夹名」为键（同一个文件夹名可以同时存在于多个编码空间，只用文件夹名会串味）。已在进行中的成员，落区与操作条都不接受新指令。

**所有异步操作走同一条串行队列**，而非各自并发。原因是 `WorkspaceManager` 的写入方法（`upsertMember` / `setMemberMode` / `savePublicSpace`）都是「读清单 → 改 → 整文件写回」，两个并发操作落在同一个编码空间时会互相覆盖，导致其中一个成员从清单里消失。按成员键去重不能解决这个问题——两个键不同的操作照样写同一个 `workspace.json`。串行化的代价是两次克隆排队而非并行，可以接受：每张卡片各自显示进行中状态，用户看得到排队。

异步覆盖的操作：clone（拖入 Git 模式）、`switchToGit`、`switchToSymlink`、`syncMember`、`clonePublicProject`、`moveMember`。瞬时操作（建软链接、`setBranch`、清单读写）仍走同步 `run`。

`moveMember` 归入异步是因为它底层是 `FileManager.moveItem`：同卷是瞬时改名，跨卷则退化为整目录复制。编码空间路径由用户任意选择，跨卷完全可能，所以统一走异步路径而非赌它快。

失败时卡片抖动并移除，同时走 alert。

## 六、代码分层

`Gojo` 是 executableTarget，`GojoCoreTests` 只依赖 `GojoCore`，所以视图层逻辑目前一行都测不到。下沉四项不依赖 SwiftUI 的纯逻辑到 `GojoCore`：

1. **`Route` 及其迁移规则**：进入、返回、进入投放模式的合法转换。
2. **`DragPayload` 编解码**：现藏在 `SidebarView` 的 private enum 内。
3. **来源图标映射表**（第 4.1 节的四值 `kind` → 底图 / 角标 / 角标色，含 `MemberForm → kind` 转换）：现在 `SidebarView.icon(for:)` 与 `DetailView.icon(for:)` 各有一份重复实现，本就该合并。映射表只返回 SF Symbol 名与色值语义，不引入 SwiftUI 依赖。
4. **轮播焦点计算**：给定各卡中心点与视口中心，算出焦点索引。

视图层按 Route 拆分，一个文件一个职责：

```
Sources/Gojo/Views/
├── ShelfView.swift            展示柜轮播容器 + 焦点驱动
├── ShelfCard.swift            空间卡片（焦点态 / 侧卡态 / 落区态）
├── PublicSpaceDomain.swift    公共空间领域
├── CodingSpaceDomain.swift    编码空间领域
├── MemberCard.swift           成员卡片 + 悬停操作条
├── ProjectTray.swift          底部公共项目托盘
├── DropZones.swift            双落区
└── SourceBadgeIcon.swift      底图 + 来源角标
```

`SidebarView.swift` 删除。`DetailView.swift` 内容拆入两个 domain 视图后删除。`ContentView.swift` 改为 Route 分发 + 全局 alert 兜底。

`AppState` 的改动限于四处，其余保持原样：`selection: SidebarSelection?` 换成 `route: Route`；`selectedFolderURL` 改为按 `route` 求值（`.shelf` 与 `.shelfDropping` 返回 `nil`，两个领域返回各自文件夹）；新增 `runAsync` 与进行中集合；`ToolbarButtons` 从全局工具栏移入两个领域顶栏。

## 七、错误处理

保留现有 `errorMessage` + alert 作为兜底，但把可预见的错误前移为视觉状态，避免弹窗打断拖拽。只有真实失败才弹 alert：

| 情况 | 处理 |
|------|------|
| 公共项目未克隆 → 软链接 | 软链接落区置灰不可放 |
| 成员名冲突 `memberNameCollision` | 落位前显示冲突提示，落区不可放 |
| 跨空间移动到源空间自身 | 源空间卡不亮落区 |
| clone / 网络失败等真实失败 | 进行中卡片抖动并移除 + alert |

## 八、测试策略

`GojoCoreTests` 现有 35 个测试全部保留。新增测试都落在 `GojoCore` 的纯逻辑上：

- `Route` 转换：展示柜 ↔ 两种领域、进入/退出投放模式。
- `DragPayload` 往返编解码，含成员 payload 与公共项目 payload 的区分。
- 图标映射覆盖三种 `MemberForm` 及托盘态。
- 焦点计算边界：空列表、单卡、滚到最左/最右端。

动画与拖放本身不写自动化测试——`XCTest` 覆盖 SwiftUI 拖放的成本远超收益。这部分靠手动验证，实现计划中会列出逐条验收步骤。

## 九、明确不做（YAGNI）

- 卡片自定义排序与自定义封面（等真有十几个空间再说）。
- 展示柜搜索框（焦点轮播 + `←→` 够用）。
- 旧 `SidebarSelection` 的兼容垫片（直接替换）。
- 成员卡片的 remote / 最近提交等扩展信息（本次只到分支名）。

# Gojo 展示柜交互界面 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans（本次由主会话内联执行）. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Gojo 的侧边栏树界面替换为「商品展示柜」——焦点轮播首页、领域展开转场、来源角标图标语言、编码空间内双落区拖入公共项目。

**Architecture:** 单窗口路由（`Route` 状态机）取代 `NavigationSplitView`；不依赖 SwiftUI 的纯逻辑（路由迁移、拖拽 payload、图标映射、焦点计算）下沉到 `GojoCore` 并做 TDD；视图层按 Route 拆成聚焦的小文件；耗时的 git 操作走单条串行队列异步执行，卡片显示进行中态。

**Tech Stack:** Swift 5.9 / SwiftUI / macOS 13+；`matchedGeometryEffect` 做领域展开；`NSEvent.addLocalMonitorForEvents` 兜底拖拽结束；`XCTest` 覆盖 GojoCore 纯逻辑。

## Global Constraints

- 领域模型不变：三种 `MemberForm`（standalone / publicGit / publicSymlink）、`MemberMode`（git / symlink）、两层结构，全部沿用 `WorkspaceManager` 既有语义。
- 品牌四色，不引入新色：Core Blue `#3B82F6`、Light Blue `#60A5FA`、Deep Ink `#111827`、Slate `#374151`。深色渐变底 `#0C1424 → #16213A`。
- 图标用系统 SF Symbols：`shippingbox` / `arrow.triangle.branch` / `link` / `globe` / `plus`。
- `accessibilityReduceMotion` 打开时所有动画退化为交叉淡入。
- 所有异步操作走**同一条串行队列**（避免并发写同一 `workspace.json` 互相覆盖）。
- 回复、注释、文档一律中文。
- 现有 35 个 `GojoCoreTests` 全部保持通过。

## 文件结构

**GojoCore 新增（纯逻辑，可测）：**
- `Sources/GojoCore/Models/Route.swift` — 路由枚举 + 合法迁移
- `Sources/GojoCore/Models/DragPayload.swift` — 拖拽 payload 编解码（从 `SidebarView` 迁出）
- `Sources/GojoCore/Models/SourceIconKind.swift` — 四值枚举 + `MemberForm→kind` + 图标/角标/色名映射
- `Sources/GojoCore/Models/CarouselFocus.swift` — 给定各卡中心点算焦点索引

**Gojo 视图层新增：**
- `Sources/Gojo/Views/Motion.swift` — 动画常量集
- `Sources/Gojo/Views/SourceBadgeIcon.swift` — 底图 + 来源角标
- `Sources/Gojo/Views/ShelfView.swift` — 轮播容器 + 焦点驱动
- `Sources/Gojo/Views/ShelfCard.swift` — 空间卡（焦点/侧卡/落区态）
- `Sources/Gojo/Views/CodingSpaceDomain.swift` — 编码空间领域
- `Sources/Gojo/Views/MemberCard.swift` — 成员卡 + 悬停操作条
- `Sources/Gojo/Views/ProjectTray.swift` — 底部公共项目托盘
- `Sources/Gojo/Views/DropZones.swift` — 双落区 + NSEvent 兜底
- `Sources/Gojo/Views/PublicSpaceDomain.swift` — 公共空间领域

**Gojo 修改：**
- `Sources/Gojo/AppState.swift` — `selection`→`route`；`runAsync`+串行队列+`busyMembers`；`selectedFolderURL` 按 route
- `Sources/Gojo/Views/ContentView.swift` — Route 分发 + 全局 alert
- `Sources/Gojo/Views/ToolbarButtons.swift` — 保留，移入两个领域顶栏

**删除：** `SidebarView.swift`、`DetailView.swift`

**测试新增：** `Tests/GojoCoreTests/RouteTests.swift`、`DragPayloadTests.swift`、`SourceIconKindTests.swift`、`CarouselFocusTests.swift`

---

### Task 1: SourceIconKind 图标映射（GojoCore 纯逻辑）

统一 `SidebarView.icon(for:)` 与 `DetailView.icon(for:)` 的重复实现，并支持托盘里「未加入的公共项目」态。

**Files:**
- Create: `Sources/GojoCore/Models/SourceIconKind.swift`
- Test: `Tests/GojoCoreTests/SourceIconKindTests.swift`

**Interfaces:**
- Produces:
  - `enum SourceIconKind { case standalone, publicGit, publicSymlink, unjoinedPublic }`
  - `init(_ form: MemberForm)` — 三态 `MemberForm` → 前三个 kind
  - `var baseSymbol: String`（`shippingbox` 或 `globe`）
  - `var badgeSymbol: String?`（角标 SF Symbol，无角标为 nil）
  - `var badgeColorName: String?`（`"coreBlue"` / `"lightBlue"`，无为 nil）

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import GojoCore

final class SourceIconKindTests: XCTestCase {
    func testFromMemberFormCoversThreeForms() {
        XCTAssertEqual(SourceIconKind(.standalone), .standalone)
        XCTAssertEqual(SourceIconKind(.publicGit(UUID())), .publicGit)
        XCTAssertEqual(SourceIconKind(.publicSymlink(UUID())), .publicSymlink)
    }
    func testBaseSymbol() {
        XCTAssertEqual(SourceIconKind.standalone.baseSymbol, "shippingbox")
        XCTAssertEqual(SourceIconKind.publicGit.baseSymbol, "shippingbox")
        XCTAssertEqual(SourceIconKind.publicSymlink.baseSymbol, "shippingbox")
        XCTAssertEqual(SourceIconKind.unjoinedPublic.baseSymbol, "globe")
    }
    func testBadge() {
        XCTAssertNil(SourceIconKind.standalone.badgeSymbol)
        XCTAssertEqual(SourceIconKind.publicGit.badgeSymbol, "arrow.triangle.branch")
        XCTAssertEqual(SourceIconKind.publicGit.badgeColorName, "coreBlue")
        XCTAssertEqual(SourceIconKind.publicSymlink.badgeSymbol, "link")
        XCTAssertEqual(SourceIconKind.publicSymlink.badgeColorName, "lightBlue")
        XCTAssertNil(SourceIconKind.unjoinedPublic.badgeSymbol)
    }
}
```

- [ ] **Step 2: 跑测试确认失败** — `swift test --filter SourceIconKindTests`，预期编译失败（类型未定义）
- [ ] **Step 3: 写实现** — 按 Interfaces 定义枚举与计算属性；`init(_ form: MemberForm)` 用 switch 映射
- [ ] **Step 4: 跑测试确认通过** — `swift test --filter SourceIconKindTests`
- [ ] **Step 5: 提交** — `git add` 两文件，`git commit -m "feat: SourceIconKind 图标映射下沉到 GojoCore"`

---

### Task 2: DragPayload 编解码（GojoCore 纯逻辑）

把藏在 `SidebarView` private enum 里的拖拽 payload 迁出并加测试。成员 payload 与公共项目裸 UUID 串需能区分。

**Files:**
- Create: `Sources/GojoCore/Models/DragPayload.swift`
- Test: `Tests/GojoCoreTests/DragPayloadTests.swift`

**Interfaces:**
- Produces:
  - `enum DragPayload`
  - `static func member(space: URL, folder: String) -> String`
  - `static func parseMember(_ s: String) -> (space: URL, folder: String)?`（非成员格式返回 nil）
  - `static func publicProject(_ id: UUID) -> String`（= `id.uuidString`）
  - `static func parsePublicProject(_ s: String) -> UUID?`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import GojoCore

final class DragPayloadTests: XCTestCase {
    func testMemberRoundTrip() {
        let space = URL(fileURLWithPath: "/tmp/电商中台")
        let s = DragPayload.member(space: space, folder: "order-api")
        let parsed = DragPayload.parseMember(s)
        XCTAssertEqual(parsed?.space, space)
        XCTAssertEqual(parsed?.folder, "order-api")
    }
    func testPublicProjectNotParsedAsMember() {
        let s = DragPayload.publicProject(UUID())
        XCTAssertNil(DragPayload.parseMember(s))
    }
    func testMemberNotParsedAsPublicProject() {
        let s = DragPayload.member(space: URL(fileURLWithPath: "/tmp/x"), folder: "a")
        XCTAssertNil(DragPayload.parsePublicProject(s))
    }
    func testPublicProjectRoundTrip() {
        let id = UUID()
        XCTAssertEqual(DragPayload.parsePublicProject(DragPayload.publicProject(id)), id)
    }
}
```

- [ ] **Step 2: 跑测试确认失败** — `swift test --filter DragPayloadTests`
- [ ] **Step 3: 写实现** — 沿用现有三行文本 + `gojo-member` 哨兵格式；`parsePublicProject` 直接 `UUID(uuidString:)`（成员格式含换行，天然不是合法 UUID）
- [ ] **Step 4: 跑测试确认通过**
- [ ] **Step 5: 提交** — `git commit -m "feat: DragPayload 迁出到 GojoCore 并加测试"`

---

### Task 3: Route 路由与迁移规则（GojoCore 纯逻辑）

**Files:**
- Create: `Sources/GojoCore/Models/Route.swift`
- Test: `Tests/GojoCoreTests/RouteTests.swift`

**Interfaces:**
- Produces:
  - `enum Route: Hashable { case shelf; case publicSpace; case codingSpace(URL); case shelfDropping(source: URL, folder: String) }`
  - `var domainFolder: URL?` — `.publicSpace` 需外部传公共空间 URL，故这里只对 `.codingSpace` 返回其 URL，其余 nil（`.shelf`/`.shelfDropping`/`.publicSpace` 均 nil；公共空间文件夹由 AppState 用 manager 求）
  - `func entering(_ target: Route) -> Route` — 从展示柜进入领域（合法则返回 target，否则返回 self）
  - `func back() -> Route` — 任意领域 → `.shelf`；`.shelfDropping` → 回到 `.codingSpace(source)`（拖拽取消）；`.shelf` → `.shelf`
  - `func beginDropping() -> Route?` — 仅 `.codingSpace(u)` 可进入 `.shelfDropping(source: u, folder:)`，需 folder 参数：改为 `func beginDropping(folder: String) -> Route?`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import GojoCore

final class RouteTests: XCTestCase {
    let space = URL(fileURLWithPath: "/tmp/电商中台")

    func testBackFromDomainGoesToShelf() {
        XCTAssertEqual(Route.publicSpace.back(), .shelf)
        XCTAssertEqual(Route.codingSpace(space).back(), .shelf)
    }
    func testBackFromShelfStaysShelf() {
        XCTAssertEqual(Route.shelf.back(), .shelf)
    }
    func testBeginDroppingOnlyFromCodingSpace() {
        XCTAssertEqual(Route.codingSpace(space).beginDropping(folder: "a"),
                       .shelfDropping(source: space, folder: "a"))
        XCTAssertNil(Route.shelf.beginDropping(folder: "a"))
        XCTAssertNil(Route.publicSpace.beginDropping(folder: "a"))
    }
    func testBackFromDroppingReturnsToSource() {
        XCTAssertEqual(Route.shelfDropping(source: space, folder: "a").back(),
                       .codingSpace(space))
    }
    func testDomainFolder() {
        XCTAssertEqual(Route.codingSpace(space).domainFolder, space)
        XCTAssertNil(Route.shelf.domainFolder)
        XCTAssertNil(Route.publicSpace.domainFolder)
    }
}
```

- [ ] **Step 2: 跑测试确认失败** — `swift test --filter RouteTests`
- [ ] **Step 3: 写实现** — 按上面测试定义枚举与方法（去掉无参 `beginDropping`，只保留 `beginDropping(folder:)`）
- [ ] **Step 4: 跑测试确认通过**
- [ ] **Step 5: 提交** — `git commit -m "feat: Route 路由状态机（含投放中间态）下沉到 GojoCore"`

---

### Task 4: CarouselFocus 焦点计算（GojoCore 纯逻辑）

给定各卡中心 x 坐标与视口中心 x，算出焦点索引。边界：空列表、单卡、滚到两端。

**Files:**
- Create: `Sources/GojoCore/Models/CarouselFocus.swift`
- Test: `Tests/GojoCoreTests/CarouselFocusTests.swift`

**Interfaces:**
- Produces:
  - `enum CarouselFocus`
  - `static func nearestIndex(cardCentersX: [CGFloat], viewportCenterX: CGFloat) -> Int?` — 返回离视口中心最近的卡索引；空数组返回 nil
  - `static func clampedIndex(_ i: Int, count: Int) -> Int` — 键盘步进用，夹到 `[0, count-1]`；count==0 返回 0

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
import CoreGraphics
@testable import GojoCore

final class CarouselFocusTests: XCTestCase {
    func testEmptyReturnsNil() {
        XCTAssertNil(CarouselFocus.nearestIndex(cardCentersX: [], viewportCenterX: 100))
    }
    func testSingleCard() {
        XCTAssertEqual(CarouselFocus.nearestIndex(cardCentersX: [50], viewportCenterX: 999), 0)
    }
    func testPicksNearest() {
        let centers: [CGFloat] = [0, 100, 200, 300]
        XCTAssertEqual(CarouselFocus.nearestIndex(cardCentersX: centers, viewportCenterX: 170), 2)
        XCTAssertEqual(CarouselFocus.nearestIndex(cardCentersX: centers, viewportCenterX: 40), 0)
        XCTAssertEqual(CarouselFocus.nearestIndex(cardCentersX: centers, viewportCenterX: 290), 3)
    }
    func testClamp() {
        XCTAssertEqual(CarouselFocus.clampedIndex(-1, count: 3), 0)
        XCTAssertEqual(CarouselFocus.clampedIndex(5, count: 3), 2)
        XCTAssertEqual(CarouselFocus.clampedIndex(1, count: 3), 1)
        XCTAssertEqual(CarouselFocus.clampedIndex(0, count: 0), 0)
    }
}
```

- [ ] **Step 2: 跑测试确认失败** — `swift test --filter CarouselFocusTests`
- [ ] **Step 3: 写实现** — `nearestIndex` 用 `enumerated().min(by: abs 差值)`；`clampedIndex` 用 `max(0, min(i, count-1))`，count<=0 返回 0
- [ ] **Step 4: 跑测试确认通过**
- [ ] **Step 5: 提交** — `git commit -m "feat: CarouselFocus 焦点计算下沉到 GojoCore"`

**验收 GojoCore 全绿：** `swift test` 应从 35 个增至 35 + 新增（约 14 个），全过。

---

### Task 5: AppState 路由化 + 异步执行 + 骨架 ContentView（大切换点）

这是构建的断裂点：`selection`→`route` 会让 `SidebarView`/`DetailView` 编译失败，故本任务一并删除旧视图、把 `ContentView` 换成能编译的占位分发。完成后 app 能构建能运行（界面暂时是空壳），后续任务逐个领域填肉。

**Files:**
- Modify: `Sources/Gojo/AppState.swift`
- Modify: `Sources/Gojo/Views/ContentView.swift`
- Delete: `Sources/Gojo/Views/SidebarView.swift`、`Sources/Gojo/Views/DetailView.swift`

**Interfaces:**
- Produces（AppState 新 API，后续视图消费）：
  - `@Published var route: Route`（初值 `.shelf`）
  - `@Published var busyMembers: Set<String>`（键 = `"\(spacePath)\u{1}\(folder)"`，用 `busyKey(space:folder:)` 生成）
  - `func busyKey(space: URL, folder: String) -> String`
  - `func isBusy(space: URL, folder: String) -> Bool`
  - `func runAsync(space: URL, folder: String, _ work: @escaping () throws -> Void)` — 入队串行队列；开始前标 busy、`reload` 后清 busy；失败设 `errorMessage`
  - `var publicSpaceFolder: URL?`（= `try? manager.publicSpaceURL()`）
  - `selectedFolderURL` 改为按 `route`：`.codingSpace(u)`→u；`.publicSpace`→`publicSpaceFolder`；`.shelf`/`.shelfDropping`→nil
  - 保留同步 `run`；`ToolbarButtons` 仍存在

- [ ] **Step 1: 改 AppState** — 见下方代码骨架

```swift
// 串行队列 + 主线程回填
private let asyncQueue = DispatchQueue(label: "io.gojo.workspace.serial")

func busyKey(space: URL, folder: String) -> String { "\(space.path)\u{1}\(folder)" }
func isBusy(space: URL, folder: String) -> Bool { busyMembers.contains(busyKey(space: space, folder: folder)) }

func runAsync(space: URL, folder: String, _ work: @escaping () throws -> Void) {
    let key = busyKey(space: space, folder: folder)
    guard !busyMembers.contains(key) else { return }
    busyMembers.insert(key)
    asyncQueue.async { [weak self] in
        do { try work(); DispatchQueue.main.async { self?.busyMembers.remove(key); self?.reload() } }
        catch { DispatchQueue.main.async { self?.busyMembers.remove(key); self?.errorMessage = "\(error)"; self?.reload() } }
    }
}
```

将 `selection: SidebarSelection?` 替换为 `route: Route = .shelf`；删除 `SidebarSelection` 枚举（迁至 Route）；`selectedFolderURL` 依 route 求值；把原先直接调用 `run { ... }` 的耗时操作（`clonePublicProject`、`addPublicToSpace(.git)`、`switchToGit`、`switchToSymlink`、`syncMember`、`moveMember`）改为 `runAsync`，瞬时操作（`addPublicToSpace(.symlink)`、`setBranch`、`setPublicSpace`、`createCodingSpace`、`addPublicProject`）保留 `run`。

- [ ] **Step 2: 删除旧视图** — `git rm Sources/Gojo/Views/SidebarView.swift Sources/Gojo/Views/DetailView.swift`
- [ ] **Step 3: 骨架 ContentView** — Route 分发到占位 Text + 全局 alert：

```swift
struct ContentView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        Group {
            switch state.route {
            case .shelf: Text("展示柜")             // Task 7 替换
            case .publicSpace: Text("公共空间")       // Task 10
            case .codingSpace(let u): Text(u.lastPathComponent)  // Task 8
            case .shelfDropping: Text("投放中")       // Task 11
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .alert("操作失败", isPresented: Binding(
            get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } })) {
            Button("好") { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "") }
    }
}
```

移除 `GojoApp`/`ContentView` 里对 `NavigationSplitView`、`ToolbarButtons` 全局工具栏的引用（工具栏后续进领域顶栏）。

- [ ] **Step 4: 构建** — `swift build`，预期通过；`swift test` 仍 35+ 全绿
- [ ] **Step 5: 提交** — `git commit -m "refactor: AppState 路由化 + 串行异步执行，删除侧边栏/详情视图"`

---

### Task 6: SourceBadgeIcon 视图 + Motion 常量 + 品牌色扩展

**Files:**
- Create: `Sources/Gojo/Views/SourceBadgeIcon.swift`
- Create: `Sources/Gojo/Views/Motion.swift`

**Interfaces:**
- Produces:
  - `extension Color { static let coreBlue, lightBlue, deepInk, slate; static func badge(_ name: String?) -> Color }`
  - `enum Motion { static let domain: Animation; static let badge: Animation; static let dropZone: Animation; static let breathe: Animation; static func gridStagger(_ i: Int) -> Double }`
  - `struct SourceBadgeIcon: View { init(kind: SourceIconKind, size: CGFloat, badgeBackground: Color) }` — 底图 + 右下角圆形角标（角标外圈描边取 `badgeBackground`）；进行中态由外部覆盖，不在此组件内

- [ ] **Step 1: 写 Motion.swift** — `domain = .spring(response:0.42, dampingFraction:0.82)`；`badge = .easeInOut(duration:0.2)`；`dropZone = .easeInOut(duration:0.18)`；`breathe = .easeInOut(duration:3.6).repeatForever(autoreverses:true)`；`gridStagger(i) = Double(i) * 0.08`
- [ ] **Step 2: 写品牌色扩展** — 四个 `Color(red:green:blue:)` 常量；`badge(_:)` 把 `"coreBlue"`/`"lightBlue"` 映射到色，nil→clear
- [ ] **Step 3: 写 SourceBadgeIcon** — `ZStack(alignment:.bottomTrailing)`：底图 `Image(systemName: kind.baseSymbol)`；若 `kind.badgeSymbol != nil` 叠角标 `Image` 加圆形背景 `Color.badge(kind.badgeColorName)` + `badgeBackground` 描边环
- [ ] **Step 4: 构建** — `swift build`
- [ ] **Step 5: 提交** — `git commit -m "feat: SourceBadgeIcon 视图 + Motion 常量 + 品牌色"`

---

### Task 7: ShelfView 轮播 + ShelfCard 空间卡 → 接入 .shelf

首页焦点轮播：公共空间卡（首位）+ N 编码空间卡 + 「新建」卡。双指横滑用原生滚动 + GeometryReader 上报中心；`←→` 键改焦点后 `ScrollViewReader` 居中。点焦点卡进入领域（本任务先只切 route，转场动画在 Task 12 用 matchedGeometry 收口）。

**Files:**
- Create: `Sources/Gojo/Views/ShelfCard.swift`
- Create: `Sources/Gojo/Views/ShelfView.swift`
- Modify: `Sources/Gojo/Views/ContentView.swift`（`.shelf` → `ShelfView()`）

**Interfaces:**
- Consumes: `AppState.codingSpaces`、`members(in:)`、`route`、`publicProjects`、`createCodingSpace()`、`SourceIconKind`、`SourceBadgeIcon`、`CarouselFocus`、`Motion`
- Produces:
  - `struct ShelfCard: View { enum Style { case focus, side }; init(kind:, focused: Bool, ...) }`
  - `struct ShelfView: View`
  - 卡片模型内部枚举：`enum ShelfItem { case publicSpace; case coding(URL); case newSpace }`

- [ ] **Step 1: ShelfCard** — 焦点态：空间名 + 仓库数 + 成员缩略墙（`ForEach` 成员小胶囊：`SourceBadgeIcon(size:14)` + 文件夹名，宽度超出收 `+N`）+ Light Blue 描边 + 蓝色 `.shadow` 外发光 + 呼吸浮动（`.offset(y:)` 配 `Motion.breathe`，`reduceMotion` 时禁用）。侧卡态：`scaleEffect(0.9)`、`opacity(0.42)`、`saturation(0.5)`、仅名字。公共空间卡用 `globe` 头图；新建卡用虚线描边 + `plus`。
- [ ] **Step 2: ShelfView** — `ScrollView(.horizontal)` + `ScrollViewReader`；`items = [.publicSpace] + codingSpaces.map(.coding) + [.newSpace]`；每卡包 `GeometryReader` 用 `PreferenceKey` 上报 `midX`；`onPreferenceChange` 调 `CarouselFocus.nearestIndex` 更新 `@State focusIndex`；点焦点卡：`.publicSpace`→`route=.publicSpace`、`.coding(u)`→`route=.codingSpace(u)`、`.newSpace`→`createCodingSpace()`；`.onMoveCommand(.left/.right)` 改 focusIndex 并 `scrollTo(居中, anchor:.center)`。
- [ ] **Step 3: 接入 ContentView** — `.shelf` 分支替换为 `ShelfView()`
- [ ] **Step 4: 构建 + 手动验证** — `swift build`；`swift run`：出现横向卡片带，双指滑动焦点居中放大，`←→` 切焦点，点编码空间卡切到该空间（占位），点「新建」弹选择文件夹面板。记录结果。
- [ ] **Step 5: 提交** — `git commit -m "feat: 展示柜焦点轮播 ShelfView + ShelfCard"`

---

### Task 8: CodingSpaceDomain + MemberCard + ProjectTray → 接入 .codingSpace

编码空间领域：顶栏（返回 + 空间名 + 终端/访达）、成员网格、底部公共项目托盘（本任务托盘先只做胶囊展示与拖起，双落区在 Task 9）。成员卡悬停浮出操作条。

**Files:**
- Create: `Sources/Gojo/Views/MemberCard.swift`
- Create: `Sources/Gojo/Views/ProjectTray.swift`
- Create: `Sources/Gojo/Views/CodingSpaceDomain.swift`
- Modify: `Sources/Gojo/Views/ContentView.swift`、`Sources/Gojo/Views/ToolbarButtons.swift`

**Interfaces:**
- Consumes: `AppState.members(in:)`、`isBusy`、`syncMember`、`branches`、`setBranch`、`switchToGit`、`switchToSymlink`、`memberHasLocalChanges`、`publicProjects`、`route.back()`、`openInTerminal`、`openInFinder`、`DragPayload`
- Produces:
  - `struct MemberCard: View { init(space: URL, member: ScannedMember) }` — 图标（进行中时角标位置换 `ProgressView`）、名、分支；悬停 `.onHover` 底部滑出操作条（同步 `arrow.triangle.2.circlepath` / 切分支 `arrow.triangle.branch` / 更多 `ellipsis` 菜单含转模式、移除）；`.contextMenu` 提供同样项；`onDrag` 发 `DragPayload.member(...)`
  - `struct ProjectTray: View { init(space: URL) }`
  - `struct CodingSpaceDomain: View { init(space: URL) }`

- [ ] **Step 1: MemberCard** — 卡片 + `SourceBadgeIcon(kind: SourceIconKind(member.form))`；`isBusy` 为真时角标位置叠 `ProgressView().controlSize(.small)` 且操作条禁用；操作条与 `contextMenu` 复用一个 `@ViewBuilder actions`；转软链接前若 `memberHasLocalChanges` 弹破坏性确认 `alert`（沿用 DetailView 既有逻辑）；`onDrag` 返回 `NSItemProvider(object: DragPayload.member(space:folder:) as NSString)`，preview 用小芯片
- [ ] **Step 2: ProjectTray** — 底部 `HStack`：标题「公共项目」+ `ForEach(publicProjects)` 胶囊（`SourceBadgeIcon(kind:.unjoinedPublic,size:14)` + 名）；每胶囊 `onDrag` 发 `DragPayload.publicProject(proj.id)`；空/未指定公共空间时显示占位
- [ ] **Step 3: CodingSpaceDomain** — `VStack`：顶栏（`Button 返回`{route=route.back()} + 空间名 + `ToolbarButtons()`）；成员网格 `LazyVGrid(columns:自适应)` of `MemberCard`；底部 `ProjectTray(space:)`
- [ ] **Step 4: 接入** — ContentView `.codingSpace(let u)` → `CodingSpaceDomain(space: u)`；`ToolbarButtons` 保持不变（已是独立 HStack）
- [ ] **Step 5: 构建 + 手动验证** — `swift run`：进入编码空间见成员网格、分支名、悬停操作条；点同步触发（git 成员），进行中态出现且完成后消失；切分支可用；终端/访达可用；返回回展示柜。记录结果。
- [ ] **Step 6: 提交** — `git commit -m "feat: 编码空间领域 + 成员卡悬停操作 + 公共项目托盘"`

---

### Task 9: DropZones 双落区 + NSEvent 兜底 → 托盘拖入定模式

按住托盘胶囊 → 成员网格降透明 → 浮出「Git 克隆 / 软链接」两落区，落哪边即哪个模式，零弹窗。软链接落区在项目 `cloned==false` 时置灰。用 `NSEvent` 监听 `leftMouseUp` 兜底清理悬空落区。

**Files:**
- Create: `Sources/Gojo/Views/DropZones.swift`
- Modify: `Sources/Gojo/Views/CodingSpaceDomain.swift`、`Sources/Gojo/Views/ProjectTray.swift`

**Interfaces:**
- Consumes: `AppState.addPublicToSpace(space:projectId:mode:)`、`publicProjects`、`DragPayload.parsePublicProject`
- Produces:
  - `struct DropZones: View { init(space: URL, draggingProjectId: UUID?, onDrop: (UUID, MemberMode) -> Void, onDismiss: () -> Void) }`
  - CodingSpaceDomain 新增 `@State draggingProjectId: UUID?`；胶囊 `onDrag` 时置该 id，触发落区出现（`Motion.dropZone`）

- [ ] **Step 1: DropZones** — 覆盖层 `HStack` 两区：Git 区（蓝虚线）、软链接区（浅蓝虚线，`cloned==false` 时 `.grayscale(1).allowsHitTesting(false)` + 提示「需先 Clone」）；每区 `onDrop(of:[.text])` 解析 `parsePublicProject` 后调 `onDrop(id, .git/.symlink)`
- [ ] **Step 2: NSEvent 兜底** — DropZones `.onAppear` 装 `NSEvent.addLocalMonitorForEvents(matching:.leftMouseUp){ e in DispatchQueue.main.async{ onDismiss() }; return e }`，`.onDisappear` `removeMonitor`；`onDismiss` 清 `draggingProjectId`（拖到窗外/Esc 也能收起落区）
- [ ] **Step 3: 接入 CodingSpaceDomain** — 当 `draggingProjectId != nil` 时 `ZStack` 叠 `DropZones`，成员网格 `.opacity(0.35)`；`onDrop` 回调 `state.addPublicToSpace` 后清 id；胶囊拖起设置 id
- [ ] **Step 4: 构建 + 手动验证** — `swift run`：从托盘拖公共项目，成员网格淡下、两落区浮出；落 Git 区 → 克隆（进行中态）后成为 git 成员；落软链接区（项目已 clone）→ 成软链接成员；未 clone 项目软链接区置灰;拖到窗外松手落区消失无残留。记录结果。
- [ ] **Step 5: 提交** — `git commit -m "feat: 双落区拖入定模式 + NSEvent 拖拽结束兜底"`

---

### Task 10: PublicSpaceDomain → 接入 .publicSpace

公共空间领域：顶栏（返回 + 终端/访达）、项目列表（名/URL/已克隆或 Clone 按钮）、新增项目、未指定公共空间时的空态引导。搬 `DetailView.publicSpaceView` 的能力。

**Files:**
- Create: `Sources/Gojo/Views/PublicSpaceDomain.swift`
- Modify: `Sources/Gojo/Views/ContentView.swift`

**Interfaces:**
- Consumes: `AppState.publicProjects`、`clonePublicProject`、`addPublicProject`、`chooseAndSetPublicSpace`、`publicSpaceFolder`、`isBusy`
- Produces: `struct PublicSpaceDomain: View`

- [ ] **Step 1: 空态** — `publicSpaceFolder == nil` 时显居中引导 + 「指定公共空间文件夹」按钮 → `chooseAndSetPublicSpace()`
- [ ] **Step 2: 已指定态** — 顶栏（返回 + 空间名 + 终端/访达）；`List(publicProjects)`：名 + URL + （`cloned` 显示已克隆 / 否则 Clone 按钮，`isBusy` 时转圈）；工具栏「+」弹新增项目 alert（名 + URL）沿用既有
- [ ] **Step 3: 接入** — ContentView `.publicSpace` → `PublicSpaceDomain()`
- [ ] **Step 4: 构建 + 手动验证** — `swift run`：轮播首位公共空间卡进入；未指定时见引导；指定后见项目列表、新增、Clone（进行中态）；返回。记录结果。
- [ ] **Step 5: 提交** — `git commit -m "feat: 公共空间领域（含空态引导）"`

---

### Task 11: 跨空间移动（投放模式）→ .shelfDropping

拖成员卡片往上 → 领域视觉收回展示柜 → 其余空间卡变落区（源空间不亮）→ 松手落入。源视图必须留在层级中（否则拖拽被系统取消），故「收回」是纯视觉叠加。

**Files:**
- Modify: `Sources/Gojo/Views/CodingSpaceDomain.swift`、`Sources/Gojo/Views/ShelfCard.swift`、`Sources/Gojo/Views/ContentView.swift`
- Consumes: `AppState.moveMember`、`route.beginDropping(folder:)`、`DragPayload.parseMember`

- [ ] **Step 1: 触发投放** — CodingSpaceDomain 顶部加一条隐形「拖到此处移动到其他空间」放置带；成员 `onDrag` 开始时不改 route（拖拽期视图不能动），改为该放置带 `onDrop` 命中或成员拖动进入顶部区域时 `route = route.beginDropping(folder:)`。简化实现：顶部放置带 `.onDrop` 命中即 `beginDropping`，落区展示柜叠加显示
- [ ] **Step 2: ShelfCard 落区态** — 新增 `droppable: Bool` 与 `isSource: Bool`；`.shelfDropping` 时展示柜卡片变虚线落区，源空间卡 `isSource` 不亮、不接收；每卡 `onDrop` 解析 `parseMember`，目标≠源则 `state.moveMember(folder, from: source, to: dest)`（走 runAsync）后 `route=.shelf`
- [ ] **Step 3: ContentView .shelfDropping** — `ZStack{ CodingSpaceDomain(space: source).scaleEffect(收回).opacity(...); ShelfView(droppingFor: (source,folder)) }`
- [ ] **Step 4: 构建 + 手动验证** — `swift run`：编码空间内把成员拖向顶部 → 展示柜收回叠现、其余空间卡成落区、源卡不亮；落到另一空间 → 成员移动（进行中态）、回到展示柜；Esc/窗外松手回原空间。记录结果。
- [ ] **Step 5: 提交** — `git commit -m "feat: 跨空间移动投放模式（.shelfDropping）"`

---

### Task 12: 领域展开转场 + reduceMotion 收口 + 全量手动验收

用 `matchedGeometryEffect` 把焦点卡与领域标题绑同一几何 ID，做「卡片放大铺满 + 成员网格错峰浮现」；`accessibilityReduceMotion` 时全退化为交叉淡入；跑一遍完整验收清单。

**Files:**
- Modify: `ShelfView.swift`、`ShelfCard.swift`、`CodingSpaceDomain.swift`、`PublicSpaceDomain.swift`、`ContentView.swift`

- [ ] **Step 1: matchedGeometry** — `@Namespace ns` 提到 ContentView，向下传；焦点 ShelfCard 与领域根容器共用 `matchedGeometryEffect(id: routeGeometryID, in: ns)`；进入/返回用 `withAnimation(Motion.domain)` 切 route；成员网格 `MemberCard` 按 index `.transition(.opacity)` + `Motion.gridStagger(i)` 延迟
- [ ] **Step 2: reduceMotion** — 读 `@Environment(\.accessibilityReduceMotion)`；为真时 `Motion` 相关 `withAnimation` 传 `nil`，呼吸浮动禁用，转场用 `.opacity`
- [ ] **Step 3: 构建 + 全量验收** — `swift build` + `swift test`（全绿）+ `swift run` 走下方清单
- [ ] **Step 4: 提交** — `git commit -m "feat: 领域展开转场 + reduceMotion 收口"`

**手动验收清单（Step 3 逐条记录）：**
1. 展示柜双指横滑，焦点卡居中放大发光并呼吸浮动
2. `←→` 键切焦点并居中
3. 点编码空间焦点卡 → 领域展开动画（卡片放大 + 网格错峰浮现）
4. 成员卡三种形态角标正确（无 / 蓝⑂ / 浅蓝🔗）
5. 悬停成员卡浮出操作条；右键同项
6. git 成员同步/切分支可用，进行中态出现与消失
7. publicGit↔publicSymlink 转模式；转软链接有本地改动时弹破坏确认
8. 托盘拖公共项目 → 双落区浮出；落 Git 区克隆、落软链接区建链
9. 未 clone 项目软链接落区置灰；拖窗外松手落区无残留
10. 拖成员向上 → 展示柜投放；落他空间移动，源卡不亮，Esc 回原空间
11. 公共空间卡进入；未指定见引导，指定后可新增/Clone
12. 系统「减弱动态效果」开启后全部改为淡入、无浮动
13. 返回三途径（按钮 / `⌘[` / `Esc`）均回展示柜

---

## 自查结论

- **Spec 覆盖：** 九决策 + 两假设逐条对应 Task 1–12；错误处理（第七节）落在 Task 8/9/10 的视觉态 + Task 5 的 alert 兜底；测试策略（第八节）= Task 1–4 的 TDD + Task 7–12 的手动清单。
- **类型一致：** `SourceIconKind`、`DragPayload`、`Route`、`CarouselFocus` 的签名在 Task 1–4 定义，Task 5–12 消费处名称一致；`runAsync(space:folder:_:)`、`busyKey`、`isBusy` 在 Task 5 定义，Task 8–11 一致使用。
- **已知风险：** 视图层不做单测（成本 > 收益），靠 Task 12 手动清单兜底；`matchedGeometryEffect` 跨 route 的连续性可能需微调，若动画割裂则退化为 Task 5 骨架里的简单切换（不阻塞功能）。

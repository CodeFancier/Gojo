# Gojo 扁平化与公共项目模式 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Gojo 从「公共空间→编码空间→开发项目→仓库」三层，重构为「公共空间→编码空间→成员仓库」两层扁平模型，并实现公共项目清单驱动（定义+按需 clone）、编码空间自动识别仓库与实时分支、公共项目以软链接/Git 模式拖入及模式互切。

**Architecture:** 沿用 SwiftPM 双 target。`GojoCore` 承载模型/配置/服务/编排，全程 TDD（`swift test`）。`Gojo`（SwiftUI）薄 UI 层，`swift build` + 手动冒烟。成员真相以**文件系统扫描为准**，`.gojo/workspace.json` 只记录「绑定了公共项目」的成员（来源+模式）；独立仓库纯扫描。公共空间以 `.gojo/public.json` 清单为准，兼容扫描补录。

**Tech Stack:** Swift 5.9+、SwiftUI、AppKit、Foundation（Process/FileManager）、XCTest、系统 `git`。

## Global Constraints

- 平台：macOS 13+（`Package.swift` 已声明 `.macOS(.v13)`，不改）。
- Git 操作一律经 `ShellRunner` 调系统 `git`，复用用户认证。
- 软链接方向固定：**编码空间成员路径 → 公共空间某公共项目的本地 clone**。
- Git 模式克隆源固定：**公共项目的远程 URL**（非公共库本地）。
- 配置存储：中心索引 `~/Library/Application Support/Gojo/index.json`（不变）+ 公共空间 `.gojo/public.json`（新增）+ 编码空间 `.gojo/workspace.json`（重构）。
- 公共空间全局唯一 1 个；编码空间多个；编码空间直接装成员仓库（无开发项目层）。
- 分支不落盘，一律实时读。
- 终端可选项固定三种：`Terminal` / `iTerm2` / `Warp`（不改）。
- 不做旧「开发项目」数据迁移垫片（YAGNI）。
- 所有服务路径参数用 `URL`，可注入以便临时目录测试。

---

## 文件结构

```
Sources/GojoCore/
├── Models/
│   ├── PublicProject.swift        [新增] {id,name,url,cloned}
│   ├── PublicSpaceManifest.swift  [新增] {projects:[PublicProject]}
│   ├── MemberMode.swift           [新增] enum .git/.symlink
│   ├── WorkspaceMember.swift      [新增] {id,folderName,publicProjectId,mode}
│   ├── WorkspaceManifest.swift    [重构] {name, members:[WorkspaceMember]}
│   ├── ScannedMember.swift        [新增] 运行态 {folderName,form,branch} + MemberForm
│   ├── GitRepoBinding.swift       [删除]
│   ├── SymlinkBinding.swift       [删除]
│   ├── ProjectManifest.swift      [删除]
│   └── CentralIndex.swift         [不变]
├── Config/
│   ├── ManifestPaths.swift        [改] 加 publicSpaceManifest，删 projectManifest
│   └── ConfigStore.swift          [改] 加 public 读写，改 workspace 类型，删 project 读写
├── Services/
│   ├── ShellRunner.swift          [不变]
│   ├── GitService.swift           [改] 加 hasUncommittedChanges/hasUnpushedCommits
│   ├── SymlinkService.swift       [不变]
│   └── ExternalAppLauncher.swift  [不变]
└── WorkspaceManager.swift         [重构] 扁平 API

Sources/Gojo/
├── AppState.swift                 [重构] SidebarSelection 两态 + 新方法
├── Views/
│   ├── SidebarView.swift          [重构] 编码空间展开成员
│   ├── DetailView.swift           [重构] 公共项目 clone / 成员模式切换
│   ├── ContentView.swift          [不变]
│   └── ToolbarButtons.swift       [不变]
```

**责任划分：** Models 仅数据+Codable（ScannedMember 是运行态，不落盘）；ConfigStore 负责 JSON 落盘；GitService 增补脏状态检测；WorkspaceManager 编排扁平操作；UI 只调 AppState。

---

## Task 1: 扁平化数据模型

**Files:**
- Create: `Sources/GojoCore/Models/PublicProject.swift`
- Create: `Sources/GojoCore/Models/PublicSpaceManifest.swift`
- Create: `Sources/GojoCore/Models/MemberMode.swift`
- Create: `Sources/GojoCore/Models/WorkspaceMember.swift`
- Create: `Sources/GojoCore/Models/ScannedMember.swift`
- Modify: `Sources/GojoCore/Models/WorkspaceManifest.swift`（整文件替换）
- Delete: `Sources/GojoCore/Models/GitRepoBinding.swift`
- Delete: `Sources/GojoCore/Models/SymlinkBinding.swift`
- Delete: `Sources/GojoCore/Models/ProjectManifest.swift`
- Test: `Tests/GojoCoreTests/ModelCodableTests.swift`（整文件替换）

**Interfaces:**
- Consumes: 无。
- Produces:
  - `PublicProject { id: UUID, name: String, url: String, cloned: Bool }`
  - `PublicSpaceManifest { projects: [PublicProject] }`
  - `MemberMode: String enum { git, symlink }`
  - `WorkspaceMember { id: UUID, folderName: String, publicProjectId: UUID, mode: MemberMode }`
  - `WorkspaceManifest { name: String, members: [WorkspaceMember] }`
  - `MemberForm enum { standalone, publicGit(UUID), publicSymlink(UUID) }`
  - `ScannedMember { folderName: String, form: MemberForm, branch: String? }`（Identifiable，id=folderName）

- [ ] **Step 1: 删除三个废弃模型文件**

```bash
git rm Sources/GojoCore/Models/GitRepoBinding.swift \
       Sources/GojoCore/Models/SymlinkBinding.swift \
       Sources/GojoCore/Models/ProjectManifest.swift
```

- [ ] **Step 2: 写新模型文件**

`Sources/GojoCore/Models/PublicProject.swift`:
```swift
import Foundation

public struct PublicProject: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var url: String
    /// 是否已在公共空间本地克隆
    public var cloned: Bool

    public init(id: UUID = UUID(), name: String, url: String, cloned: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.cloned = cloned
    }
}
```

`Sources/GojoCore/Models/PublicSpaceManifest.swift`:
```swift
import Foundation

public struct PublicSpaceManifest: Codable, Equatable {
    public var projects: [PublicProject]
    public init(projects: [PublicProject] = []) { self.projects = projects }
}
```

`Sources/GojoCore/Models/MemberMode.swift`:
```swift
import Foundation

public enum MemberMode: String, Codable, Hashable {
    case git, symlink
}
```

`Sources/GojoCore/Models/WorkspaceMember.swift`:
```swift
import Foundation

/// 仅记录「绑定了公共项目」的成员；独立仓库不入清单。
public struct WorkspaceMember: Codable, Identifiable, Hashable {
    public var id: UUID
    /// 编码空间内的直接子文件夹名
    public var folderName: String
    /// 来源公共项目 id
    public var publicProjectId: UUID
    public var mode: MemberMode

    public init(id: UUID = UUID(), folderName: String,
                publicProjectId: UUID, mode: MemberMode) {
        self.id = id
        self.folderName = folderName
        self.publicProjectId = publicProjectId
        self.mode = mode
    }
}
```

`Sources/GojoCore/Models/ScannedMember.swift`:
```swift
import Foundation

/// 编码空间成员的运行态形态（扫描得到，不落盘）。
public enum MemberForm: Hashable {
    case standalone              // 含 .git、未绑定公共项目
    case publicGit(UUID)         // 含 .git、绑定公共项目（Git 模式）
    case publicSymlink(UUID)     // 符号链接指向公共项目
}

public struct ScannedMember: Identifiable, Hashable {
    public var folderName: String
    public var form: MemberForm
    /// git 仓库实时分支；读不到为 nil
    public var branch: String?

    public var id: String { folderName }

    public init(folderName: String, form: MemberForm, branch: String?) {
        self.folderName = folderName
        self.form = form
        self.branch = branch
    }
}
```

- [ ] **Step 3: 重构 WorkspaceManifest（整文件替换）**

`Sources/GojoCore/Models/WorkspaceManifest.swift`:
```swift
import Foundation

public struct WorkspaceManifest: Codable, Equatable {
    public var name: String
    /// 仅绑定了公共项目的成员；独立仓库靠扫描发现，不在此列。
    public var members: [WorkspaceMember]

    public init(name: String, members: [WorkspaceMember] = []) {
        self.name = name
        self.members = members
    }
}
```

- [ ] **Step 4: 替换 ModelCodableTests（整文件替换）**

`Tests/GojoCoreTests/ModelCodableTests.swift`:
```swift
import XCTest
@testable import GojoCore

final class ModelCodableTests: XCTestCase {
    func testPublicSpaceManifestRoundTrip() throws {
        let manifest = PublicSpaceManifest(projects: [
            PublicProject(name: "shared-lib", url: "git@example.com:shared-lib.git", cloned: false),
            PublicProject(name: "payment-core", url: "git@example.com:payment.git", cloned: true),
        ])
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(PublicSpaceManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
    }

    func testWorkspaceManifestRoundTrip() throws {
        let pid = UUID()
        let manifest = WorkspaceManifest(name: "电商中台", members: [
            WorkspaceMember(folderName: "shared-lib", publicProjectId: pid, mode: .symlink),
            WorkspaceMember(folderName: "payment-core", publicProjectId: UUID(), mode: .git),
        ])
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(WorkspaceManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
    }

    func testCentralIndexDefaults() {
        let index = CentralIndex()
        XCTAssertNil(index.publicSpacePath)
        XCTAssertEqual(index.terminalPreference, .terminal)
    }
}
```

- [ ] **Step 5: 运行测试（此时应编译失败——ConfigStore 仍引用旧类型）**

Run: `swift build 2>&1 | head -30`
Expected: 编译错误集中在 `ConfigStore.swift`（`ProjectManifest`/`loadProject` 等未定义）与 `WorkspaceManager.swift`。这是预期的，Task 2/8 修复。**本 task 先不追求整体编译通过**，仅确认新模型文件本身语法无误：

Run: `swift build --target GojoCore 2>&1 | grep -E "Models/(PublicProject|PublicSpaceManifest|MemberMode|WorkspaceMember|ScannedMember|WorkspaceManifest)" || echo "no-model-errors"`
Expected: 打印 `no-model-errors`（模型文件无报错；其余报错来自尚未改的 ConfigStore/WorkspaceManager）。

- [ ] **Step 6: 提交**

```bash
git add Sources/GojoCore/Models Tests/GojoCoreTests/ModelCodableTests.swift
git commit -m "refactor: 扁平化数据模型（公共项目清单 + 编码空间成员）"
```

---

## Task 2: ConfigStore + ManifestPaths 适配新清单

**Files:**
- Modify: `Sources/GojoCore/Config/ManifestPaths.swift`（整文件替换）
- Modify: `Sources/GojoCore/Config/ConfigStore.swift`（整文件替换）
- Modify: `Tests/GojoCoreTests/ConfigStoreTests.swift`（整文件替换）

**Interfaces:**
- Consumes: Task 1 模型；`CentralIndex`（不变）。
- Produces:
  - `ManifestPaths.gojoDir(in:)`、`.workspaceManifest(in:)`、`.publicSpaceManifest(in:)` → `URL`。
  - `ConfigStore`：`loadIndex()->CentralIndex`、`saveIndex(_:)`、`loadPublicSpace(at:)->PublicSpaceManifest?`、`savePublicSpace(_:at:)`、`loadWorkspace(at:)->WorkspaceManifest?`、`saveWorkspace(_:at:)`。

- [ ] **Step 1: 替换 ManifestPaths（整文件替换）**

`Sources/GojoCore/Config/ManifestPaths.swift`:
```swift
import Foundation

public enum ManifestPaths {
    public static func gojoDir(in root: URL) -> URL {
        root.appendingPathComponent(".gojo", isDirectory: true)
    }
    public static func workspaceManifest(in root: URL) -> URL {
        gojoDir(in: root).appendingPathComponent("workspace.json")
    }
    public static func publicSpaceManifest(in root: URL) -> URL {
        gojoDir(in: root).appendingPathComponent("public.json")
    }
}
```

- [ ] **Step 2: 替换 ConfigStore（整文件替换）**

`Sources/GojoCore/Config/ConfigStore.swift`:
```swift
import Foundation

public struct ConfigStore {
    private let baseDirectory: URL
    private let fm = FileManager.default

    public init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                      in: .userDomainMask)[0]
            self.baseDirectory = appSupport.appendingPathComponent("Gojo", isDirectory: true)
        }
    }

    private var indexURL: URL { baseDirectory.appendingPathComponent("index.json") }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try encoder().encode(value).write(to: url, options: .atomic)
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard fm.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    // 中心索引
    public func loadIndex() -> CentralIndex {
        (try? read(CentralIndex.self, from: indexURL)) ?? CentralIndex()
    }
    public func saveIndex(_ index: CentralIndex) throws {
        try write(index, to: indexURL)
    }

    // 公共空间清单
    public func loadPublicSpace(at root: URL) throws -> PublicSpaceManifest? {
        try read(PublicSpaceManifest.self, from: ManifestPaths.publicSpaceManifest(in: root))
    }
    public func savePublicSpace(_ manifest: PublicSpaceManifest, at root: URL) throws {
        try write(manifest, to: ManifestPaths.publicSpaceManifest(in: root))
    }

    // 编码空间清单
    public func loadWorkspace(at root: URL) throws -> WorkspaceManifest? {
        try read(WorkspaceManifest.self, from: ManifestPaths.workspaceManifest(in: root))
    }
    public func saveWorkspace(_ manifest: WorkspaceManifest, at root: URL) throws {
        try write(manifest, to: ManifestPaths.workspaceManifest(in: root))
    }
}
```

- [ ] **Step 3: 替换 ConfigStoreTests（整文件替换）**

`Tests/GojoCoreTests/ConfigStoreTests.swift`:
```swift
import XCTest
@testable import GojoCore

final class ConfigStoreTests: XCTestCase {
    func testIndexRoundTrip() throws {
        let base = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: base)
        var index = store.loadIndex()
        XCTAssertNil(index.publicSpacePath)

        index.publicSpacePath = "/tmp/public"
        index.codingSpacePaths = ["/tmp/ws1"]
        index.terminalPreference = .iterm2
        try store.saveIndex(index)

        XCTAssertEqual(ConfigStore(baseDirectory: base).loadIndex(), index)
    }

    func testPublicSpaceManifestRoundTrip() throws {
        let space = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: try TestSupport.makeTempDir())
        XCTAssertNil(try store.loadPublicSpace(at: space))

        let manifest = PublicSpaceManifest(projects: [
            PublicProject(name: "lib", url: "git@x:lib.git", cloned: false)
        ])
        try store.savePublicSpace(manifest, at: space)
        XCTAssertEqual(try store.loadPublicSpace(at: space), manifest)
    }

    func testWorkspaceManifestRoundTrip() throws {
        let ws = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: try TestSupport.makeTempDir())
        XCTAssertNil(try store.loadWorkspace(at: ws))

        let manifest = WorkspaceManifest(name: "电商中台", members: [
            WorkspaceMember(folderName: "lib", publicProjectId: UUID(), mode: .symlink)
        ])
        try store.saveWorkspace(manifest, at: ws)
        XCTAssertEqual(try store.loadWorkspace(at: ws), manifest)
    }
}
```

- [ ] **Step 4: 运行测试**

Run: `swift test --filter ConfigStoreTests 2>&1 | tail -20`
Expected: 若 `WorkspaceManager.swift` 尚未改会整体编译失败。为隔离验证，本步接受「ConfigStore/Model 测试因 WorkspaceManager 报错而无法运行」，将在 Task 8 后统一转绿。仅确认 ConfigStore 本身无编译错误：

Run: `swift build --target GojoCore 2>&1 | grep "Config/ConfigStore" || echo "configstore-ok"`
Expected: 打印 `configstore-ok`。

- [ ] **Step 5: 提交**

```bash
git add Sources/GojoCore/Config Tests/GojoCoreTests/ConfigStoreTests.swift
git commit -m "refactor: ConfigStore 适配公共空间/编码空间新清单"
```

---

## Task 3: GitService 脏状态检测

**Files:**
- Modify: `Sources/GojoCore/Services/GitService.swift`（追加方法）
- Modify: `Tests/GojoCoreTests/GitServiceTests.swift`（追加测试）

**Interfaces:**
- Consumes: Task 2 之前已有的私有 `git(_:at:)`、`shell`。
- Produces: `hasUncommittedChanges(at: URL) throws -> Bool`、`hasUnpushedCommits(at: URL) throws -> Bool`。

- [ ] **Step 1: 追加失败测试**

在 `GitServiceTests` 类内追加：
```swift
    func testUncommittedChangesDetected() throws {
        let sandbox = try TestSupport.makeTempDir()
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        let dest = sandbox.appendingPathComponent("clone")
        let git = GitService()
        try git.clone(url: source.path, into: dest)

        XCTAssertFalse(try git.hasUncommittedChanges(at: dest))
        try "dirty".write(to: dest.appendingPathComponent("new.txt"),
                          atomically: true, encoding: .utf8)
        XCTAssertTrue(try git.hasUncommittedChanges(at: dest))
    }

    func testUnpushedCommitsDetected() throws {
        let sandbox = try TestSupport.makeTempDir()
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        let dest = sandbox.appendingPathComponent("clone")
        let git = GitService()
        try git.clone(url: source.path, into: dest)

        // 刚 clone，HEAD == origin/main，无未推送
        XCTAssertFalse(try git.hasUnpushedCommits(at: dest))

        // 本地新提交 → 未推送
        let shell = ShellRunner()
        _ = try shell.run("git", ["config", "user.email", "t@t.io"], cwd: dest)
        _ = try shell.run("git", ["config", "user.name", "t"], cwd: dest)
        try "x".write(to: dest.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        _ = try shell.run("git", ["add", "."], cwd: dest)
        _ = try shell.run("git", ["commit", "-q", "-m", "local"], cwd: dest)
        XCTAssertTrue(try git.hasUnpushedCommits(at: dest))
    }

    func testNoUpstreamTreatedAsUnpushed() throws {
        let sandbox = try TestSupport.makeTempDir()
        // makeLocalGitRepo 建的是本地初始化仓库，无上游
        let repo = try TestSupport.makeLocalGitRepo(named: "solo", in: sandbox)
        XCTAssertTrue(try GitService().hasUnpushedCommits(at: repo))
    }
```

- [ ] **Step 2: 运行确认失败**

Run: `swift test --filter GitServiceTests 2>&1 | tail -15`
Expected: 编译失败或断言失败（方法未定义）。

- [ ] **Step 3: 实现两方法**

在 `GitService` 中，`pull(at:)` 方法之后追加：
```swift
    /// 工作区有未提交改动（含未跟踪文件）。
    public func hasUncommittedChanges(at repo: URL) throws -> Bool {
        let out = try git(["status", "--porcelain"], at: repo)
        return !out.isEmpty
    }

    /// 有未推送到上游的提交；无上游按「有风险」处理（返回 true）。
    public func hasUnpushedCommits(at repo: URL) throws -> Bool {
        let upstream = try shell.run(
            "git", ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], cwd: repo)
        if upstream.exitCode != 0 { return true }   // 无上游 → 风险
        let log = try git(["log", "@{u}..HEAD", "--oneline"], at: repo)
        return !log.isEmpty
    }
```

- [ ] **Step 4: 运行确认通过**

Run: `swift test --filter GitServiceTests 2>&1 | tail -15`
Expected: PASS（原有 + 3 个新用例）。注意：若 `WorkspaceManager.swift` 仍未改导致整体编译失败，先临时把 `WorkspaceManager.swift` 内容替换为空壳（见 Task 4 会整体重写）——但推荐按 Task 顺序执行到 Task 8 后统一 `swift test` 转绿。此步仅要求 GitService 目标编译通过：

Run: `swift build --target GojoCore 2>&1 | grep "Services/GitService" || echo "gitservice-ok"`
Expected: 打印 `gitservice-ok`。

- [ ] **Step 5: 提交**

```bash
git add Sources/GojoCore/Services/GitService.swift Tests/GojoCoreTests/GitServiceTests.swift
git commit -m "feat: GitService 未提交/未推送改动检测"
```

---

## Task 4: WorkspaceManager 重写（骨架 + 公共空间）

> 本 task 用**整文件替换** `WorkspaceManager.swift`，一次性给出扁平 API 全貌（后续 Task 5–7 的测试逐块验证各方法）。这样避免中间态编译不过。

**Files:**
- Modify: `Sources/GojoCore/WorkspaceManager.swift`（整文件替换）
- Modify: `Tests/GojoCoreTests/WorkspaceManagerTests.swift`（整文件替换为公共空间用例，Task 5–7 追加）

**Interfaces:**
- Consumes: Task 1–3 全部模型与服务。
- Produces（本 task 起对外可见的完整 API）：
  - 公共空间：`setPublicSpace(_:)`、`publicSpaceURL()`、`addPublicProject(name:url:)`、`clonePublicProject(id:)`、`publicProjects()`。
  - 编码空间：`createCodingSpace(name:at:)`、`scanMembers(in:)`、`addPublicProjectToSpace(projectId:mode:in:)`、`memberHasLocalChanges(folderName:in:)`、`switchToGit(folderName:in:)`、`switchToSymlink(folderName:in:)`、`listBranches(folderName:in:)`、`setBranch(_:folderName:in:)`、`syncMember(folderName:in:)`。
  - `WorkspaceError`：`.noPublicSpace`、`.publicProjectNotFound(UUID)`、`.publicProjectNotCloned(String)`、`.memberNotFound(String)`、`.notASymlinkMember(String)`、`.notAGitMember(String)`。

- [ ] **Step 1: 整文件替换 WorkspaceManager.swift**

`Sources/GojoCore/WorkspaceManager.swift`:
```swift
import Foundation

public enum WorkspaceError: Error, Equatable {
    case noPublicSpace
    case publicProjectNotFound(UUID)
    case publicProjectNotCloned(String)
    case memberNotFound(String)
    case notASymlinkMember(String)
    case notAGitMember(String)
}

public final class WorkspaceManager {
    private let store: ConfigStore
    private let git: GitService
    private let symlink: SymlinkService
    private let fm = FileManager.default

    public init(configStore: ConfigStore,
                git: GitService = GitService(),
                symlink: SymlinkService = SymlinkService()) {
        self.store = configStore
        self.git = git
        self.symlink = symlink
    }

    // MARK: - 公共空间

    public func setPublicSpace(_ url: URL) throws {
        var index = store.loadIndex()
        index.publicSpacePath = url.path
        try store.saveIndex(index)
    }

    public func publicSpaceURL() throws -> URL {
        guard let p = store.loadIndex().publicSpacePath else { throw WorkspaceError.noPublicSpace }
        return URL(fileURLWithPath: p)
    }

    /// 仅登记定义，不立即 clone。
    public func addPublicProject(name: String, url: String) throws {
        let space = try publicSpaceURL()
        var m = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        m.projects.append(PublicProject(name: name, url: url, cloned: false))
        try store.savePublicSpace(m, at: space)
    }

    /// 对 cloned=false 的项执行 clone，成功后置 cloned=true。
    public func clonePublicProject(id: UUID) throws {
        let space = try publicSpaceURL()
        var m = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        guard let i = m.projects.firstIndex(where: { $0.id == id }) else {
            throw WorkspaceError.publicProjectNotFound(id)
        }
        let proj = m.projects[i]
        try git.clone(url: proj.url, into: space.appendingPathComponent(proj.name))
        m.projects[i].cloned = true
        try store.savePublicSpace(m, at: space)
    }

    /// 合并清单与扫描：刷新 cloned 标志，补录扫描到但清单缺失的库；持久化后返回。
    public func publicProjects() throws -> [PublicProject] {
        let space = try publicSpaceURL()
        var m = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()

        // 1) 刷新已有项的 cloned 状态
        for i in m.projects.indices {
            let path = space.appendingPathComponent(m.projects[i].name).path
            m.projects[i].cloned = fm.fileExists(atPath: path)
        }
        // 2) 扫描补录：子目录含 .git 且清单无同名者
        let entries = (try? fm.contentsOfDirectory(at: space,
            includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for entry in entries {
            let name = entry.lastPathComponent
            guard name != ".gojo" else { continue }
            guard fm.fileExists(atPath: entry.appendingPathComponent(".git").path) else { continue }
            guard !m.projects.contains(where: { $0.name == name }) else { continue }
            let origin = (try? git.remoteURL(at: entry)) ?? ""
            m.projects.append(PublicProject(name: name, url: origin, cloned: true))
        }
        try store.savePublicSpace(m, at: space)
        return m.projects.sorted { $0.name < $1.name }
    }

    // MARK: - 编码空间

    public func createCodingSpace(name: String, at url: URL) throws {
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try store.saveWorkspace(WorkspaceManifest(name: name), at: url)
        var index = store.loadIndex()
        if !index.codingSpacePaths.contains(url.path) { index.codingSpacePaths.append(url.path) }
        try store.saveIndex(index)
    }

    /// 扫描直接子文件夹，识别成员形态并实时读分支。
    public func scanMembers(in codingSpace: URL) throws -> [ScannedMember] {
        let manifest = (try store.loadWorkspace(at: codingSpace))
            ?? WorkspaceManifest(name: codingSpace.lastPathComponent)
        let entries = (try? fm.contentsOfDirectory(at: codingSpace,
            includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])) ?? []

        var result: [ScannedMember] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = entry.lastPathComponent
            guard name != ".gojo" else { continue }
            let isLink = (try? entry.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
            let bound = manifest.members.first { $0.folderName == name }

            let form: MemberForm
            if isLink {
                guard let b = bound, b.mode == .symlink else { continue } // 未知符号链接，跳过
                form = .publicSymlink(b.publicProjectId)
            } else {
                guard fm.fileExists(atPath: entry.appendingPathComponent(".git").path) else { continue }
                if let b = bound, b.mode == .git { form = .publicGit(b.publicProjectId) }
                else { form = .standalone }
            }
            let branch = try? git.currentBranch(at: entry)
            result.append(ScannedMember(folderName: name, form: form, branch: branch))
        }
        return result
    }

    /// 把公共项目以指定模式落入编码空间，并记入清单。
    public func addPublicProjectToSpace(projectId: UUID, mode: MemberMode,
                                        in codingSpace: URL) throws {
        let (proj, space) = try lookupPublicProject(projectId)
        let dest = codingSpace.appendingPathComponent(proj.name)

        switch mode {
        case .git:
            try git.clone(url: proj.url, into: dest)
        case .symlink:
            guard proj.cloned else { throw WorkspaceError.publicProjectNotCloned(proj.name) }
            try symlink.createSymlink(at: dest, pointingTo: space.appendingPathComponent(proj.name))
        }
        try upsertMember(WorkspaceMember(folderName: proj.name,
                                         publicProjectId: proj.id, mode: mode), in: codingSpace)
    }

    public func memberHasLocalChanges(folderName: String, in codingSpace: URL) throws -> Bool {
        let path = codingSpace.appendingPathComponent(folderName)
        return try git.hasUncommittedChanges(at: path) || git.hasUnpushedCommits(at: path)
    }

    /// 软链接成员 → Git 模式：删链接、从远程 URL clone。
    public func switchToGit(folderName: String, in codingSpace: URL) throws {
        let member = try member(folderName, in: codingSpace)
        guard member.mode == .symlink else { throw WorkspaceError.notASymlinkMember(folderName) }
        let (proj, _) = try lookupPublicProject(member.publicProjectId)
        let dest = codingSpace.appendingPathComponent(folderName)
        try fm.removeItem(at: dest)                    // 删符号链接（不动 target）
        try git.clone(url: proj.url, into: dest)
        try setMemberMode(folderName, to: .git, in: codingSpace)
    }

    /// Git 模式成员 → 软链接：删本地 clone、建链接指向公共库。调用方须先处理确认。
    public func switchToSymlink(folderName: String, in codingSpace: URL) throws {
        let member = try member(folderName, in: codingSpace)
        guard member.mode == .git else { throw WorkspaceError.notAGitMember(folderName) }
        let (proj, space) = try lookupPublicProject(member.publicProjectId)
        guard proj.cloned else { throw WorkspaceError.publicProjectNotCloned(proj.name) }
        let dest = codingSpace.appendingPathComponent(folderName)
        try fm.removeItem(at: dest)                    // 删整个本地 clone
        try symlink.createSymlink(at: dest, pointingTo: space.appendingPathComponent(proj.name))
        try setMemberMode(folderName, to: .symlink, in: codingSpace)
    }

    public func listBranches(folderName: String, in codingSpace: URL) throws -> [String] {
        try git.listBranches(at: codingSpace.appendingPathComponent(folderName))
    }

    public func setBranch(_ branch: String, folderName: String, in codingSpace: URL) throws {
        try git.checkout(branch: branch, at: codingSpace.appendingPathComponent(folderName))
    }

    public func syncMember(folderName: String, in codingSpace: URL) throws {
        try git.pull(at: codingSpace.appendingPathComponent(folderName))
    }

    // MARK: - 私有辅助

    private func lookupPublicProject(_ id: UUID) throws -> (PublicProject, URL) {
        let space = try publicSpaceURL()
        let m = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        guard let proj = m.projects.first(where: { $0.id == id }) else {
            throw WorkspaceError.publicProjectNotFound(id)
        }
        return (proj, space)
    }

    private func member(_ folderName: String, in codingSpace: URL) throws -> WorkspaceMember {
        let m = (try store.loadWorkspace(at: codingSpace))
            ?? WorkspaceManifest(name: codingSpace.lastPathComponent)
        guard let member = m.members.first(where: { $0.folderName == folderName }) else {
            throw WorkspaceError.memberNotFound(folderName)
        }
        return member
    }

    private func upsertMember(_ member: WorkspaceMember, in codingSpace: URL) throws {
        var m = (try store.loadWorkspace(at: codingSpace))
            ?? WorkspaceManifest(name: codingSpace.lastPathComponent)
        if let i = m.members.firstIndex(where: { $0.folderName == member.folderName }) {
            m.members[i] = member
        } else {
            m.members.append(member)
        }
        try store.saveWorkspace(m, at: codingSpace)
    }

    private func setMemberMode(_ folderName: String, to mode: MemberMode,
                               in codingSpace: URL) throws {
        var m = (try store.loadWorkspace(at: codingSpace))
            ?? WorkspaceManifest(name: codingSpace.lastPathComponent)
        guard let i = m.members.firstIndex(where: { $0.folderName == folderName }) else {
            throw WorkspaceError.memberNotFound(folderName)
        }
        m.members[i].mode = mode
        try store.saveWorkspace(m, at: codingSpace)
    }
}
```

- [ ] **Step 2: GitService 补 remoteURL（publicProjects 补录需要）**

在 `GitService`（Task 3 追加之后）再加：
```swift
    /// 读取 origin 远程 URL；无则抛错。
    public func remoteURL(at repo: URL) throws -> String {
        try git(["remote", "get-url", "origin"], at: repo)
    }
```

- [ ] **Step 3: 整文件替换 WorkspaceManagerTests（公共空间用例）**

`Tests/GojoCoreTests/WorkspaceManagerTests.swift`:
```swift
import XCTest
@testable import GojoCore

final class WorkspaceManagerTests: XCTestCase {
    // 建一个已设定公共空间的 manager，返回 (manager, publicSpaceURL, sandbox)
    func makeWithPublicSpace() throws -> (WorkspaceManager, URL, URL) {
        let sandbox = try TestSupport.makeTempDir()
        let publicSpace = sandbox.appendingPathComponent("public")
        try FileManager.default.createDirectory(at: publicSpace, withIntermediateDirectories: true)
        let mgr = WorkspaceManager(configStore: ConfigStore(baseDirectory: try TestSupport.makeTempDir()))
        try mgr.setPublicSpace(publicSpace)
        return (mgr, publicSpace, sandbox)
    }

    func testAddPublicProjectDefinitionOnly() throws {
        let (mgr, _, _) = try makeWithPublicSpace()
        try mgr.addPublicProject(name: "lib", url: "git@x:lib.git")
        let projects = try mgr.publicProjects()
        XCTAssertEqual(projects.map { $0.name }, ["lib"])
        XCTAssertFalse(projects[0].cloned)      // 只定义，未克隆
    }

    func testClonePublicProjectSetsCloned() throws {
        let (mgr, publicSpace, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id

        try mgr.clonePublicProject(id: id)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: publicSpace.appendingPathComponent("lib/README.md").path))
        XCTAssertTrue(try mgr.publicProjects().first { $0.name == "lib" }!.cloned)
    }

    func testPublicProjectsAutoDetectsScannedRepo() throws {
        let (mgr, publicSpace, sandbox) = try makeWithPublicSpace()
        // 直接在公共空间放一个已 clone 的库（不经 addPublicProject）
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        try GitService().clone(url: source.path, into: publicSpace.appendingPathComponent("manual"))

        let projects = try mgr.publicProjects()
        XCTAssertTrue(projects.contains { $0.name == "manual" && $0.cloned })
    }
}
```

- [ ] **Step 4: 运行全量测试转绿**

Run: `swift test 2>&1 | tail -25`
Expected: 全部 PASS（Model / ConfigStore / Shell / Git / Symlink / ExternalApp / WorkspaceManager 公共空间用例）。此时整个 GojoCore 编译通过。

- [ ] **Step 5: 提交**

```bash
git add Sources/GojoCore/WorkspaceManager.swift Sources/GojoCore/Services/GitService.swift Tests/GojoCoreTests/WorkspaceManagerTests.swift
git commit -m "refactor: WorkspaceManager 扁平化 API + 公共空间清单驱动"
```

---

## Task 5: 编码空间成员扫描测试

**Files:**
- Modify: `Tests/GojoCoreTests/WorkspaceManagerTests.swift`（追加）

**Interfaces:**
- Consumes: Task 4 的 `scanMembers`、`createCodingSpace`、`addPublicProjectToSpace`。

- [ ] **Step 1: 追加扫描测试**

在 `WorkspaceManagerTests` 追加：
```swift
    func testScanIdentifiesStandaloneAndBranch() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        // 手动往编码空间丢一个独立仓库
        let source = try TestSupport.makeLocalGitRepo(named: "s", in: sandbox)
        try GitService().clone(url: source.path, into: ws.appendingPathComponent("solo"))

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members[0].folderName, "solo")
        XCTAssertEqual(members[0].form, .standalone)
        XCTAssertEqual(members[0].branch, "main")     // 实时读分支
    }

    func testScanIdentifiesPublicGitMember() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id

        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try mgr.addPublicProjectToSpace(projectId: id, mode: .git, in: ws)

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members[0].form, .publicGit(id))
    }

    func testScanIdentifiesPublicSymlinkMember() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id
        try mgr.clonePublicProject(id: id)             // 软链接要求先克隆

        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try mgr.addPublicProjectToSpace(projectId: id, mode: .symlink, in: ws)

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members[0].form, .publicSymlink(id))
    }

    func testSymlinkModeRequiresClonedPublic() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        try mgr.addPublicProject(name: "lib", url: "git@x:lib.git")   // 未克隆
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)

        XCTAssertThrowsError(try mgr.addPublicProjectToSpace(projectId: id, mode: .symlink, in: ws)) {
            XCTAssertEqual($0 as? WorkspaceError, .publicProjectNotCloned("lib"))
        }
    }
```

- [ ] **Step 2: 运行测试**

Run: `swift test --filter WorkspaceManagerTests 2>&1 | tail -20`
Expected: PASS（含新增 4 用例）。

- [ ] **Step 3: 提交**

```bash
git add Tests/GojoCoreTests/WorkspaceManagerTests.swift
git commit -m "test: 编码空间成员扫描与形态识别"
```

---

## Task 6: 模式切换测试（含脏工作区拦截）

**Files:**
- Modify: `Tests/GojoCoreTests/WorkspaceManagerTests.swift`（追加）

**Interfaces:**
- Consumes: Task 4 的 `switchToGit`、`switchToSymlink`、`memberHasLocalChanges`。

- [ ] **Step 1: 追加模式切换测试**

在 `WorkspaceManagerTests` 追加：
```swift
    // 建好「公共项目已克隆 + 编码空间已以 symlink 模式加入」的场景
    private func setupSymlinkMember() throws -> (WorkspaceManager, URL, UUID, URL) {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        try mgr.addPublicProject(name: "lib", url: source.path)
        let id = try mgr.publicProjects().first { $0.name == "lib" }!.id
        try mgr.clonePublicProject(id: id)
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try mgr.addPublicProjectToSpace(projectId: id, mode: .symlink, in: ws)
        return (mgr, ws, id, sandbox)
    }

    func testSwitchSymlinkToGit() throws {
        let (mgr, ws, id, _) = try setupSymlinkMember()
        try mgr.switchToGit(folderName: "lib", in: ws)

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.first?.form, .publicGit(id))
        // 现在是独立 clone，含 .git
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: ws.appendingPathComponent("lib/.git").path))
    }

    func testSwitchGitToSymlinkWhenClean() throws {
        let (mgr, ws, id, _) = try setupSymlinkMember()
        try mgr.switchToGit(folderName: "lib", in: ws)          // 先到 git
        XCTAssertFalse(try mgr.memberHasLocalChanges(folderName: "lib", in: ws))
        try mgr.switchToSymlink(folderName: "lib", in: ws)      // 干净，可直接切回

        let members = try mgr.scanMembers(in: ws)
        XCTAssertEqual(members.first?.form, .publicSymlink(id))
    }

    func testMemberHasLocalChangesDetectsDirty() throws {
        let (mgr, ws, _, _) = try setupSymlinkMember()
        try mgr.switchToGit(folderName: "lib", in: ws)
        // 制造未提交改动
        try "dirty".write(to: ws.appendingPathComponent("lib/new.txt"),
                          atomically: true, encoding: .utf8)
        XCTAssertTrue(try mgr.memberHasLocalChanges(folderName: "lib", in: ws))
    }

    func testSwitchToGitOnNonSymlinkThrows() throws {
        let (mgr, ws, _, _) = try setupSymlinkMember()
        try mgr.switchToGit(folderName: "lib", in: ws)          // 已是 git
        XCTAssertThrowsError(try mgr.switchToGit(folderName: "lib", in: ws)) {
            XCTAssertEqual($0 as? WorkspaceError, .notASymlinkMember("lib"))
        }
    }
```

- [ ] **Step 2: 运行测试**

Run: `swift test --filter WorkspaceManagerTests 2>&1 | tail -20`
Expected: PASS。

- [ ] **Step 3: 提交**

```bash
git add Tests/GojoCoreTests/WorkspaceManagerTests.swift
git commit -m "test: 软链接↔Git 模式切换与脏工作区检测"
```

---

## Task 7: 分支/同步（扁平成员）测试

**Files:**
- Modify: `Tests/GojoCoreTests/WorkspaceManagerTests.swift`（追加）

**Interfaces:**
- Consumes: Task 4 的 `listBranches`、`setBranch`、`syncMember`。

- [ ] **Step 1: 追加测试**

在 `WorkspaceManagerTests` 追加：
```swift
    func testBranchListAndCheckoutOnMember() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        _ = try ShellRunner().run("git", ["branch", "feature"], cwd: source)

        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try GitService().clone(url: source.path, into: ws.appendingPathComponent("lib"))

        XCTAssertTrue(try mgr.listBranches(folderName: "lib", in: ws).contains("feature"))
        try mgr.setBranch("feature", folderName: "lib", in: ws)
        XCTAssertEqual(try mgr.scanMembers(in: ws).first?.branch, "feature")
    }

    func testSyncMemberDoesNotThrow() throws {
        let (mgr, _, sandbox) = try makeWithPublicSpace()
        let source = try TestSupport.makeLocalGitRepo(named: "lib", in: sandbox)
        let ws = sandbox.appendingPathComponent("ws")
        try mgr.createCodingSpace(name: "ws", at: ws)
        try GitService().clone(url: source.path, into: ws.appendingPathComponent("lib"))
        XCTAssertNoThrow(try mgr.syncMember(folderName: "lib", in: ws))
    }
```

- [ ] **Step 2: 运行全量测试**

Run: `swift test 2>&1 | tail -25`
Expected: 全部 PASS。核心层重构完成。

- [ ] **Step 3: 提交**

```bash
git add Tests/GojoCoreTests/WorkspaceManagerTests.swift
git commit -m "test: 扁平成员分支切换与同步"
```

---

## Task 8: AppState 重构（两层选择 + 扁平方法）

> UI 层（Task 8–11）以 `swift build` 通过 + 手动冒烟验证，不声称自动化单测。

**Files:**
- Modify: `Sources/Gojo/AppState.swift`（整文件替换）

**Interfaces:**
- Consumes: Task 4 的 `WorkspaceManager` 全部方法、`PublicProject`、`ScannedMember`、`MemberMode`。
- Produces:
  - `SidebarSelection { publicSpace, codingSpace(URL) }`（去掉 devProject）。
  - `@Published publicProjects: [PublicProject]`、`codingSpaces: [URL]`、`membersByPath: [String: [ScannedMember]]`、`selection`、`errorMessage`。
  - 方法：`chooseAndSetPublicSpace()`、`addPublicProject(name:url:)`、`clonePublicProject(_:)`、`createCodingSpace()`、`members(in:)`、`addPublicToSpace(_:projectId:mode:)`、`memberHasLocalChanges(_:folderName:)`、`switchToGit(_:folderName:)`、`switchToSymlink(_:folderName:)`、`branches(_:folderName:)`、`setBranch(_:folderName:branch:)`、`syncMember(_:folderName:)`、`openInTerminal()`、`openInFinder()`、`terminalPreference`。

- [ ] **Step 1: 整文件替换 AppState.swift**

`Sources/Gojo/AppState.swift`:
```swift
import AppKit
import Foundation
import GojoCore

enum SidebarSelection: Hashable {
    case publicSpace
    case codingSpace(URL)
}

@MainActor
final class AppState: ObservableObject {
    @Published var publicProjects: [PublicProject] = []
    @Published var codingSpaces: [URL] = []
    @Published var membersByPath: [String: [ScannedMember]] = [:]
    @Published var selection: SidebarSelection?
    @Published var errorMessage: String?

    let manager: WorkspaceManager
    let store: ConfigStore
    private let launcher = ExternalAppLauncher()

    init() {
        self.store = ConfigStore()
        self.manager = WorkspaceManager(configStore: store)
        reload()
    }

    func reload() {
        let index = store.loadIndex()
        codingSpaces = index.codingSpacePaths.map { URL(fileURLWithPath: $0) }
        publicProjects = (try? manager.publicProjects()) ?? []
        var m: [String: [ScannedMember]] = [:]
        for space in codingSpaces {
            m[space.path] = (try? manager.scanMembers(in: space)) ?? []
        }
        membersByPath = m
    }

    func run(_ action: () throws -> Void) {
        do { try action(); reload() }
        catch { errorMessage = "\(error)" }
    }

    func members(in space: URL) -> [ScannedMember] {
        membersByPath[space.path] ?? []
    }

    // MARK: 公共空间
    func chooseAndSetPublicSpace() {
        guard let url = pickFolder(message: "选择公共空间文件夹") else { return }
        run { try manager.setPublicSpace(url) }
    }
    func addPublicProject(name: String, url: String) {
        run { try manager.addPublicProject(name: name, url: url) }
    }
    func clonePublicProject(_ id: UUID) {
        run { try manager.clonePublicProject(id: id) }
    }

    // MARK: 编码空间
    func createCodingSpace() {
        guard let url = pickFolder(message: "选择/新建编码空间文件夹") else { return }
        run { try manager.createCodingSpace(name: url.lastPathComponent, at: url) }
    }
    func addPublicToSpace(_ space: URL, projectId: UUID, mode: MemberMode) {
        run { try manager.addPublicProjectToSpace(projectId: projectId, mode: mode, in: space) }
    }
    func memberHasLocalChanges(_ space: URL, folderName: String) -> Bool {
        (try? manager.memberHasLocalChanges(folderName: folderName, in: space)) ?? false
    }
    func switchToGit(_ space: URL, folderName: String) {
        run { try manager.switchToGit(folderName: folderName, in: space) }
    }
    func switchToSymlink(_ space: URL, folderName: String) {
        run { try manager.switchToSymlink(folderName: folderName, in: space) }
    }
    func branches(_ space: URL, folderName: String) -> [String] {
        (try? manager.listBranches(folderName: folderName, in: space)) ?? []
    }
    func setBranch(_ space: URL, folderName: String, branch: String) {
        run { try manager.setBranch(branch, folderName: folderName, in: space) }
    }
    func syncMember(_ space: URL, folderName: String) {
        run { try manager.syncMember(folderName: folderName, in: space) }
    }

    // MARK: 终端 / 访达
    var terminalPreference: TerminalApp {
        get { store.loadIndex().terminalPreference }
        set { var i = store.loadIndex(); i.terminalPreference = newValue; try? store.saveIndex(i) }
    }
    var selectedFolderURL: URL? {
        switch selection {
        case .publicSpace: return try? manager.publicSpaceURL()
        case .codingSpace(let u): return u
        case .none: return nil
        }
    }
    func openInTerminal() {
        guard let url = selectedFolderURL else { return }
        run { try launcher.launch(.terminal(terminalPreference), path: url) }
    }
    func openInFinder() {
        guard let url = selectedFolderURL else { return }
        run { try launcher.launch(.finder, path: url) }
    }

    // MARK: 工具
    func pickFolder(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = message
        return panel.runModal() == .OK ? panel.url : nil
    }
}
```

- [ ] **Step 2: 编译（预期 SidebarView/DetailView 仍报错，Task 9/10 修）**

Run: `swift build 2>&1 | grep -E "Views/(Sidebar|Detail)View" | head` 
Expected: 报错集中在 SidebarView/DetailView（引用了已删的 `devProjects`/`projectManifest` 等）。AppState 本身无错。这是预期，下一 task 修复。

- [ ] **Step 3: 提交**

```bash
git add Sources/Gojo/AppState.swift
git commit -m "refactor: AppState 两层选择模型与扁平成员方法"
```

---

## Task 9: SidebarView 重构（编码空间展开成员）

**Files:**
- Modify: `Sources/Gojo/Views/SidebarView.swift`（整文件替换）

**Interfaces:**
- Consumes: Task 8 的 `AppState`（`publicProjects`、`members(in:)`、`selection`）。

- [ ] **Step 1: 整文件替换 SidebarView.swift**

`Sources/Gojo/Views/SidebarView.swift`:
```swift
import SwiftUI
import GojoCore

struct SidebarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $state.selection) {
                Section("🌐 公共空间") {
                    Label("公共空间", systemImage: "globe").tag(SidebarSelection.publicSpace)
                    ForEach(state.publicProjects) { proj in
                        HStack {
                            Image(systemName: proj.cloned ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(proj.cloned ? .green : .secondary)
                            Text(proj.name)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Section("📁 编码空间") {
                    ForEach(state.codingSpaces, id: \.self) { space in
                        DisclosureGroup {
                            ForEach(state.members(in: space)) { member in
                                HStack {
                                    Image(systemName: icon(for: member.form))
                                    Text(member.folderName)
                                    Spacer()
                                    if let b = member.branch {
                                        Text(b).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            Text(space.lastPathComponent)
                                .tag(SidebarSelection.codingSpace(space))
                        }
                    }
                }
            }
            .frame(minWidth: 240)
            HStack {
                Button("指定公共空间") { state.chooseAndSetPublicSpace() }
                Button("新建编码空间") { state.createCodingSpace() }
            }.padding(8)
        }
    }

    private func icon(for form: MemberForm) -> String {
        switch form {
        case .standalone:     return "shippingbox"          // 📦 独立
        case .publicGit:      return "arrow.triangle.branch" // ⑂ Git
        case .publicSymlink:  return "link"                  // 🔗 软链接
        }
    }
}
```

- [ ] **Step 2: 编译**

Run: `swift build 2>&1 | grep "Views/SidebarView" || echo "sidebar-ok"`
Expected: 打印 `sidebar-ok`（SidebarView 无错；DetailView 仍可能报错，Task 10 修）。

- [ ] **Step 3: 提交**

```bash
git add Sources/Gojo/Views/SidebarView.swift
git commit -m "refactor: 侧边栏公共项目克隆状态 + 编码空间成员展开"
```

---

## Task 10: DetailView 重构（公共项目 clone / 成员模式切换）

**Files:**
- Modify: `Sources/Gojo/Views/DetailView.swift`（整文件替换）

**Interfaces:**
- Consumes: Task 8 的 `AppState` 全部方法；`PublicProject`、`ScannedMember`、`MemberForm`、`MemberMode`。

- [ ] **Step 1: 整文件替换 DetailView.swift**

`Sources/Gojo/Views/DetailView.swift`:
```swift
import SwiftUI
import GojoCore

struct DetailView: View {
    @EnvironmentObject var state: AppState

    // 新增公共项目
    @State private var showAddProject = false
    @State private var newName = ""
    @State private var newURL = ""

    // 添加公共项目到空间
    @State private var showAddToSpace = false
    @State private var pendingProjectId: UUID?
    @State private var pendingMode: MemberMode = .git

    // 切分支
    @State private var branchTarget: String?
    @State private var branchOptions: [String] = []

    // Git→软链接破坏性确认
    @State private var confirmSymlinkFolder: String?

    var body: some View {
        switch state.selection {
        case .publicSpace, .none:
            publicSpaceView
        case .codingSpace(let space):
            codingSpaceView(space)
        }
    }

    // MARK: 公共空间详情
    private var publicSpaceView: some View {
        List {
            ForEach(state.publicProjects) { proj in
                HStack {
                    VStack(alignment: .leading) {
                        Text(proj.name)
                        Text(proj.url).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if proj.cloned {
                        Label("已克隆", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).labelStyle(.iconOnly)
                    } else {
                        Button("Clone") { state.clonePublicProject(proj.id) }
                    }
                }
            }
        }
        .navigationTitle("公共空间")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddProject = true } label: { Image(systemName: "plus") }
            }
        }
        .alert("新增公共项目", isPresented: $showAddProject) {
            TextField("名称", text: $newName)
            TextField("Git URL", text: $newURL)
            Button("添加") {
                state.addPublicProject(name: newName, url: newURL)
                newName = ""; newURL = ""
            }
            Button("取消", role: .cancel) {}
        } message: { Text("只登记定义，点 Clone 才同步下来") }
    }

    // MARK: 编码空间详情
    private func codingSpaceView(_ space: URL) -> some View {
        List {
            Section("成员仓库") {
                ForEach(state.members(in: space)) { member in
                    memberRow(space, member)
                }
            }
        }
        .navigationTitle(space.lastPathComponent)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(state.publicProjects) { proj in
                        Menu(proj.name) {
                            Button("Git 模式") {
                                state.addPublicToSpace(space, projectId: proj.id, mode: .git)
                            }
                            Button("软链接模式") {
                                state.addPublicToSpace(space, projectId: proj.id, mode: .symlink)
                            }
                        }
                    }
                } label: { Image(systemName: "plus") }
            }
        }
        .confirmationDialog("选择分支", isPresented: Binding(
            get: { branchTarget != nil },
            set: { if !$0 { branchTarget = nil } }), presenting: branchOptions) { branches in
            ForEach(branches, id: \.self) { b in
                Button(b) {
                    if let f = branchTarget { state.setBranch(space, folderName: f, branch: b) }
                    branchTarget = nil
                }
            }
        }
        .alert("切回软链接会丢失本地改动", isPresented: Binding(
            get: { confirmSymlinkFolder != nil },
            set: { if !$0 { confirmSymlinkFolder = nil } })) {
            Button("仍然切换", role: .destructive) {
                if let f = confirmSymlinkFolder { state.switchToSymlink(space, folderName: f) }
                confirmSymlinkFolder = nil
            }
            Button("取消", role: .cancel) { confirmSymlinkFolder = nil }
        } message: { Text("该成员的本地 clone 有未提交或未推送的改动，切回软链接将删除它们。") }
    }

    @ViewBuilder
    private func memberRow(_ space: URL, _ member: ScannedMember) -> some View {
        HStack {
            Image(systemName: icon(for: member.form))
            Text(member.folderName)
            Spacer()
            if let b = member.branch {
                Text(b).font(.caption).foregroundStyle(.secondary)
            }
            // git 成员：同步 + 切分支
            if isGit(member.form) {
                Button("同步") { state.syncMember(space, folderName: member.folderName) }
                Button("分支") {
                    branchTarget = member.folderName
                    branchOptions = state.branches(space, folderName: member.folderName)
                }
            }
            // 模式切换（仅公共项目成员）
            switch member.form {
            case .publicSymlink:
                Button("转 Git") { state.switchToGit(space, folderName: member.folderName) }
            case .publicGit:
                Button("转软链接") {
                    if state.memberHasLocalChanges(space, folderName: member.folderName) {
                        confirmSymlinkFolder = member.folderName
                    } else {
                        state.switchToSymlink(space, folderName: member.folderName)
                    }
                }
            case .standalone:
                EmptyView()
            }
        }
    }

    private func isGit(_ form: MemberForm) -> Bool {
        switch form {
        case .standalone, .publicGit: return true
        case .publicSymlink: return false
        }
    }

    private func icon(for form: MemberForm) -> String {
        switch form {
        case .standalone:    return "shippingbox"
        case .publicGit:     return "arrow.triangle.branch"
        case .publicSymlink: return "link"
        }
    }
}
```

- [ ] **Step 2: 编译**

Run: `swift build 2>&1 | tail -20`
Expected: 编译成功，无 error。

- [ ] **Step 3: 手动冒烟**

Run: `swift run`
手动走黄金路径（记录任何异常）：
1. 指定公共空间（选一个空文件夹）。
2. 新增公共项目：填名称 + 一个可访问的 git URL → 侧边栏出现「未克隆」标记。
3. 点 Clone → 变「已克隆」。
4. 新建编码空间。
5. 选中编码空间 → 工具栏 `+` → 选该公共项目 → Git 模式 → 成员出现，显示分支。
6. 成员行「转软链接」→（干净）直接切成 🔗。
7. 成员行「转 Git」→ 切回 ⑂，可切分支/同步。
8. 右上角访达打开编码空间，确认目录结构（含 clone 或符号链接）。

- [ ] **Step 4: 提交**

```bash
git add Sources/Gojo/Views/DetailView.swift
git commit -m "refactor: 详情区公共项目克隆与成员模式切换"
```

---

## Task 11: 拖拽公共项目到编码空间（含退化）

**Files:**
- Modify: `Sources/Gojo/Views/SidebarView.swift`（追加拖拽）

**Interfaces:**
- Consumes: Task 8 `addPublicToSpace`；Task 9 侧边栏结构。

- [ ] **Step 1: 公共项目行加 onDrag，编码空间行加 onDrop**

在 `SidebarView` 公共项目 `ForEach` 的 `HStack { … }` 后追加拖出（携带项目 id 字符串）：
```swift
                        .onDrag {
                            NSItemProvider(object: proj.id.uuidString as NSString)
                        }
```
在编码空间 `DisclosureGroup` 的 `label:` `Text(space.lastPathComponent)...` 之后，为该行加放入（`@State` 变量在 struct 顶部声明）：
```swift
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            guard let p = providers.first else { return false }
                            _ = p.loadObject(ofClass: NSString.self) { obj, _ in
                                guard let s = obj as? String, let id = UUID(uuidString: s) else { return }
                                DispatchQueue.main.async {
                                    dropTargetSpace = space
                                    droppedProjectId = id
                                    showModePicker = true
                                }
                            }
                            return true
                        }
```
在 `SidebarView` struct 顶部（`@EnvironmentObject` 下）声明：
```swift
    @State private var showModePicker = false
    @State private var dropTargetSpace: URL?
    @State private var droppedProjectId: UUID?
```
在最外层 `VStack` 之后追加模式选择确认：
```swift
        .confirmationDialog("选择加入模式", isPresented: $showModePicker) {
            Button("Git 模式") {
                if let s = dropTargetSpace, let id = droppedProjectId {
                    state.addPublicToSpace(s, projectId: id, mode: .git)
                }
            }
            Button("软链接模式") {
                if let s = dropTargetSpace, let id = droppedProjectId {
                    state.addPublicToSpace(s, projectId: id, mode: .symlink)
                }
            }
            Button("取消", role: .cancel) {}
        }
```
需要在文件顶部确保 `import UniformTypeIdentifiers`（`.text` 类型）。

- [ ] **Step 2: 编译**

Run: `swift build 2>&1 | tail -15`
Expected: 编译成功。

- [ ] **Step 3: 手动冒烟（拖拽）**

Run: `swift run`
把侧边栏一个公共项目拖到某个编码空间行 → 弹出「选择加入模式」→ 选 Git / 软链接 → 成员落入。
- **退化条款**：若拖拽在实测中不触发（SwiftUI List 拖放已知有平台差异），保留 Task 10 工具栏 `+` 菜单作为等效入口，并在提交信息与最终汇报中如实说明拖拽未生效、以菜单为准。不谎称拖拽可用。

- [ ] **Step 4: 提交**

```bash
git add Sources/Gojo/Views/SidebarView.swift
git commit -m "feat: 拖拽公共项目到编码空间选择模式（退化为菜单入口）"
```

---

## 自检（Self-Review）

**1. Spec 覆盖：**
- 需求1 打开编码空间自动识别 git 仓库 → Task 4 `scanMembers` + Task 5 测试 + Task 9 展示 ✓
- 需求2 编码空间内多仓库显示分支 → `scanMembers` 实时读 branch + Task 9/10 展示 ✓
- 需求3 公共项目只定义 URL、点 clone 才同步 → Task 4 `addPublicProject`(cloned=false)/`clonePublicProject` + Task 10 Clone 按钮 ✓
- 需求4 拖入 + 软链接/Git 模式 + 可切换 → Task 4 `addPublicProjectToSpace`/`switchToGit`/`switchToSymlink` + Task 6 测试 + Task 10 切换 UI + Task 11 拖拽 ✓
- 决策1 扁平化 → 删 ProjectManifest、WorkspaceManifest 重构为 members ✓
- 决策2 Git=独立 clone → `addPublicProjectToSpace(.git)` 执行 `git clone` ✓
- 决策3 从远程 URL → clone 用 `proj.url` ✓
- 决策4 清单驱动 → PublicSpaceManifest + public.json ✓
- 决策5 可切换含破坏性确认 → `memberHasLocalChanges` + Task 10 `.alert(role:.destructive)` ✓
- 扫描优先 → `scanMembers` 以文件系统为准，清单只标注绑定成员 ✓
- 不做迁移垫片 → 直接删旧模型/清单方法 ✓

**2. 占位符扫描：** 无 TBD/TODO；每个代码步骤含完整可照搬代码。Task 11 退化条款是显式行为约定，非占位。

**3. 类型一致性：**
- `MemberMode`(.git/.symlink)、`MemberForm`(.standalone/.publicGit/.publicSymlink)、`SidebarSelection`(.publicSpace/.codingSpace) 全程统一。
- WorkspaceManager 方法名：`addPublicProject`/`clonePublicProject`/`publicProjects`/`scanMembers`/`addPublicProjectToSpace`/`memberHasLocalChanges`/`switchToGit`/`switchToSymlink`/`listBranches`/`setBranch`/`syncMember` — Task 4 定义，Task 5–8 一致引用。
- `GitService` 新增 `hasUncommittedChanges`/`hasUnpushedCommits`(Task 3)、`remoteURL`(Task 4) — 引用处一致。
- `ConfigStore`：`loadPublicSpace`/`savePublicSpace`/`loadWorkspace`/`saveWorkspace`(新签名) — Task 2 定义，Task 4 引用一致。
- AppState 方法签名与 View 调用一致（`addPublicToSpace(_:projectId:mode:)` 等）。

**4. 范围：** 单一实现计划，聚焦四需求 + 扁平化重构，无跨子系统混入。

---

## 执行说明

核心层（Task 1–7）全程 TDD，`swift test` 可全绿；因是重构，采用「整文件替换 + 分块测试」策略，Task 4 一次性给出 WorkspaceManager 全貌以避免中间态编译失败。UI 层（Task 8–11）以 `swift build` + 手动冒烟验证，拖拽含退化条款，均如实标注非自动化。

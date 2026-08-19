import AppKit
import Foundation
@preconcurrency import GojoCore

@MainActor
final class AppState: ObservableObject {
    @Published var publicProjects: [PublicProject] = []
    @Published var compositePublicFolders: [PublicCompositeFolder] = []
    @Published var codingSpaces: [URL] = []
    @Published var membersByPath: [String: [ScannedMember]] = [:]
    @Published var pendingMembersByPath: [String: [PendingCodingSpaceMember]] = [:]
    @Published var route: Route = .shelf
    @Published var busyMembers: Set<String> = []
    @Published var errorMessage: String?
    @Published var codingSpaceDeletionSession: CodingSpaceDeletionSession?
    @Published var workspaceScanSession: WorkspaceScanSession?
    @Published var codingSpaceNamingSession: CodingSpaceNamingSession?

    let manager: WorkspaceManager
    let store: ConfigStore
    private let launcher = ExternalAppLauncher()
    private let memoryReader = AgentMemoryReader()
    /// 所有耗时操作走同一条串行队列：WorkspaceManager 的写入是「读清单→改→整文件写回」，
    /// 两个并发操作落在同一编码空间会互相覆盖，导致成员从清单消失。串行化根治。
    private let asyncQueue = DispatchQueue(label: "io.gojo.workspace.serial")

    init() {
        self.store = ConfigStore()
        self.manager = WorkspaceManager(configStore: store)
        reload()
    }

    func reload() {
        let index = store.loadIndex()
        codingSpaces = index.codingSpacePaths.map { URL(fileURLWithPath: $0) }
        publicProjects = (try? manager.publicProjects()) ?? []
        compositePublicFolders = (try? manager.publicCompositeFolders()) ?? []
        var m: [String: [ScannedMember]] = [:]
        for space in codingSpaces {
            m[space.path] = (try? manager.scanMembers(in: space)) ?? []
        }
        membersByPath = m
    }

    /// 瞬时操作：同步执行后立即 reload。
    func run(_ action: () throws -> Void) {
        do { try action(); reload() }
        catch { errorMessage = "\(error)" }
    }

    // MARK: 异步执行

    func busyKey(space: URL, folder: String) -> String { "\(space.path)\u{1}\(folder)" }
    func isBusy(space: URL, folder: String) -> Bool {
        busyMembers.contains(busyKey(space: space, folder: folder))
    }

    /// 耗时操作：入串行队列，开始前标 busy，完成/失败后清 busy 并 reload。
    func runAsync(space: URL, folder: String, onFinish: @escaping () -> Void = {},
                  _ work: @escaping () throws -> Void) {
        let key = busyKey(space: space, folder: folder)
        guard !busyMembers.contains(key) else { return }
        busyMembers.insert(key)
        asyncQueue.async { [weak self] in
            let failureMessage: String?
            do {
                try work()
                failureMessage = nil
            } catch {
                failureMessage = "\(error)"
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busyMembers.remove(key)
                if let failureMessage {
                    self.errorMessage = failureMessage
                }
                onFinish()
                self.reload()
            }
        }
    }

    func members(in space: URL) -> [ScannedMember] {
        membersByPath[space.path] ?? []
    }

    func pendingMembers(in space: URL) -> [PendingCodingSpaceMember] {
        pendingMembersByPath[space.path] ?? []
    }

    var publicSpaceFolder: URL? { try? manager.publicSpaceURL() }

    // MARK: 编码空间根目录
    var codingSpaceRoot: URL? { manager.codingSpaceRootURL() }
    func chooseAndSetCodingSpaceRoot() {
        guard let url = pickFolder(message: "选择编码空间根目录") else { return }
        run { try manager.setCodingSpaceRoot(url) }
    }
    func clearCodingSpaceRoot() {
        run { try manager.clearCodingSpaceRoot() }
    }
    func openCodingSpaceRootInFinder() {
        guard let root = codingSpaceRoot else { return }
        run { try launcher.launch(.finder, path: root) }
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
        guard let space = publicSpaceFolder,
              let proj = publicProjects.first(where: { $0.id == id }) else { return }
        let manager = self.manager
        runAsync(space: space, folder: proj.name) {
            try manager.clonePublicProject(id: id)
        }
    }
    func removePublicProject(_ id: UUID) {
        guard let space = publicSpaceFolder,
              let project = publicProjects.first(where: { $0.id == id }) else { return }
        let manager = self.manager
        runAsync(space: space, folder: project.name) {
            try manager.removePublicProject(id: id)
        }
    }
    func promoteNestedPublicProject(_ project: NestedPublicProject) {
        run {
            try manager.promoteNestedPublicProject(
                parentRelativePath: project.parentRelativePath, projectName: project.name)
        }
    }

    // MARK: 编码空间
    /// 新建编码空间：已设根目录 → 只弹命名 sheet，确认后在根目录下建同名文件夹；
    /// 未设根目录 → 保持 NSOpenPanel 选目录流程。
    func createCodingSpace() {
        if manager.codingSpaceRootURL() != nil {
            codingSpaceNamingSession = CodingSpaceNamingSession()
        } else {
            guard let url = pickFolder(message: "选择/新建编码空间文件夹") else { return }
            run { try manager.createCodingSpace(name: url.lastPathComponent, at: url) }
        }
    }
    /// 命名 sheet 确认：在根目录下创建空间（重名自动 _2/_3）。
    func confirmCodingSpaceCreation() {
        guard let session = codingSpaceNamingSession else { return }
        let name = WorkspaceManager.sanitizedFolderName(session.name)
        guard !name.isEmpty else { return }
        codingSpaceNamingSession = nil
        let manager = self.manager
        run {
            guard let root = manager.codingSpaceRootURL() else { return }
            _ = try manager.createCodingSpace(named: name, underRoot: root)
        }
    }
    func dismissCodingSpaceNaming() { codingSpaceNamingSession = nil }
    func setCodingSpaceName(_ name: String) { codingSpaceNamingSession?.name = name }
    func removeCodingSpace(_ space: URL, mode: CodingSpaceRemovalMode) {
        let manager = self.manager
        runAsync(space: space, folder: "__coding_space__") {
            try manager.removeCodingSpace(at: space, mode: mode)
        }
    }
    func prepareCodingSpaceDeletion(_ space: URL) {
        do {
            let items = try manager.codingSpaceRemovalItems(at: space)
            guard !items.isEmpty else {
                // 文件夹已被外部删除时无需展示一个无法执行的空任务列表，直接清理登记。
                try manager.removeCodingSpace(at: space, mode: .unregisterOnly)
                reload()
                return
            }
            codingSpaceDeletionSession = CodingSpaceDeletionSession(
                space: space, tasks: items.map { CodingSpaceDeletionTask(item: $0) })
        } catch {
            errorMessage = "\(error)"
        }
    }
    func dismissCodingSpaceDeletion() {
        guard codingSpaceDeletionSession?.phase != .deleting else { return }
        codingSpaceDeletionSession = nil
    }
    func unregisterPreparedCodingSpace() {
        guard let session = codingSpaceDeletionSession else { return }
        codingSpaceDeletionSession = nil
        removeCodingSpace(session.space, mode: .unregisterOnly)
    }
    func trashPreparedCodingSpace() {
        guard var session = codingSpaceDeletionSession, session.phase == .review else { return }
        session.phase = .deleting
        codingSpaceDeletionSession = session
        let sessionID = session.id
        let space = session.space
        let tasks = session.tasks
        let manager = self.manager

        asyncQueue.async { [weak self] in
            var rootMoved = false
            for task in tasks {
                DispatchQueue.main.async {
                    self?.updateDeletionTask(task.id, in: sessionID, status: .running)
                }
                do {
                    try manager.moveCodingSpaceRemovalItemToTrash(task.item, in: space)
                    if task.item.isRoot { rootMoved = true }
                    DispatchQueue.main.async {
                        self?.updateDeletionTask(task.id, in: sessionID, status: .completed)
                    }
                } catch {
                    let message = error.localizedDescription
                    DispatchQueue.main.async {
                        self?.updateDeletionTask(task.id, in: sessionID, status: .failed(message))
                    }
                }
            }

            if rootMoved {
                try? manager.removeCodingSpace(at: space, mode: .unregisterOnly)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if self.codingSpaceDeletionSession?.id == sessionID {
                    self.codingSpaceDeletionSession?.phase = .finished
                }
                self.reload()
            }
        }
    }

    private func updateDeletionTask(_ taskID: String, in sessionID: UUID,
                                    status: CodingSpaceDeletionTaskStatus) {
        guard codingSpaceDeletionSession?.id == sessionID,
              let index = codingSpaceDeletionSession?.tasks.firstIndex(where: { $0.id == taskID })
        else { return }
        codingSpaceDeletionSession?.tasks[index].status = status
    }
    func addPublicToSpace(_ space: URL, projectId: UUID, mode: MemberMode) {
        guard let project = publicProjects.first(where: { $0.id == projectId }) else { return }
        let folder = project.name
        guard !isBusy(space: space, folder: folder) else { return }

        var pendingMembers = pendingMembers(in: space)
        pendingMembers.removeAll { $0.folderName == folder }
        pendingMembers.append(PendingCodingSpaceMember(
            projectID: projectId,
            folderName: folder,
            mode: mode
        ))
        pendingMembersByPath[space.path] = pendingMembers

        let manager = self.manager
        runAsync(space: space, folder: folder, onFinish: { [weak self] in
            self?.removePendingMember(folder: folder, from: space)
        }) {
            try manager.addPublicProjectToSpace(projectId: projectId, mode: mode, in: space)
        }
    }

    private func removePendingMember(folder: String, from space: URL) {
        guard var pendingMembers = pendingMembersByPath[space.path] else { return }
        pendingMembers.removeAll { $0.folderName == folder }
        if pendingMembers.isEmpty {
            pendingMembersByPath.removeValue(forKey: space.path)
        } else {
            pendingMembersByPath[space.path] = pendingMembers
        }
    }
    func removeMember(_ folderName: String, from space: URL) {
        let manager = self.manager
        runAsync(space: space, folder: folderName) {
            try manager.removeMember(folderName: folderName, in: space)
        }
    }
    func memberHasLocalChanges(_ space: URL, folderName: String) -> Bool {
        (try? manager.memberHasLocalChanges(folderName: folderName, in: space)) ?? false
    }
    func switchToGit(_ space: URL, folderName: String) {
        let manager = self.manager
        runAsync(space: space, folder: folderName) {
            try manager.switchToGit(folderName: folderName, in: space)
        }
    }
    func switchToSymlink(_ space: URL, folderName: String) {
        let manager = self.manager
        runAsync(space: space, folder: folderName) {
            try manager.switchToSymlink(folderName: folderName, in: space)
        }
    }
    func branches(_ space: URL, folderName: String) -> [String] {
        (try? manager.listBranches(folderName: folderName, in: space)) ?? []
    }
    func setBranch(_ space: URL, folderName: String, branch: String) {
        run { try manager.setBranch(branch, folderName: folderName, in: space) }
    }
    func syncMember(_ space: URL, folderName: String) {
        let manager = self.manager
        runAsync(space: space, folder: folderName) {
            try manager.syncMember(folderName: folderName, in: space)
        }
    }

    // MARK: 终端 / 访达
    var terminalPreference: TerminalApp {
        get { store.loadIndex().terminalPreference }
        set { var i = store.loadIndex(); i.terminalPreference = newValue; try? store.saveIndex(i) }
    }
    var selectedFolderURL: URL? {
        switch route {
        case .publicSpace: return publicSpaceFolder
        case .codingSpace(let u): return u
        case .shelf, .shelfDropping: return nil
        }
    }
    func openInTerminal() {
        guard let url = selectedFolderURL else {
            // 首页等路线没有选中目录，明确提示而不是静默无反应
            // （偏好此时已被菜单处理程序写入，用户会以为点了没效果）。
            errorMessage = "当前页面没有可打开的文件夹，请先进入一个空间"
            return
        }
        run { try launcher.launch(.terminal(terminalPreference), path: url) }
    }
    func openInFinder() {
        guard let url = selectedFolderURL else { return }
        run { try launcher.launch(.finder, path: url) }
    }

    // MARK: 助手记忆 / 历史会话
    /// 后台读取某目录（成员或编码空间根）下 Claude/Codex 的记忆与会话快照，读完回主线程。
    func loadAgentMemory(projectURL: URL, kind: AgentKind,
                         completion: @escaping (AgentMemorySnapshot) -> Void) {
        let reader = memoryReader
        asyncQueue.async {
            let snap = reader.snapshot(for: kind, projectPath: projectURL)
            DispatchQueue.main.async { completion(snap) }
        }
    }

    /// 在偏好终端里 resume 指定会话（cd 到该目录后执行 claude/codex resume）。
    func resumeSession(projectURL: URL, kind: AgentKind, sessionId: String) {
        let term = terminalPreference
        do { try launcher.resume(kind, sessionId: sessionId, cwd: projectURL, terminal: term) }
        catch { errorMessage = "\(error)" }
    }

    // MARK: 搜索根目录下的已存在项目

    /// 列出编码空间根目录下的已存在文件夹，等待用户勾选登记。
    func startWorkspaceScan() {
        guard let root = manager.codingSpaceRootURL() else {
            errorMessage = "请先在首页顶部设置编码空间根目录，再搜索已存在项目"
            return
        }
        let session = WorkspaceScanSession()
        workspaceScanSession = session
        let sessionID = session.id
        let manager = self.manager
        asyncQueue.async { [weak self] in
            let folders = (try? manager.existingProjectFolders(underRoot: root)) ?? []
            let results = folders.map {
                WorkspaceScanResult(project: $0, isSelected: true, status: .idle)
            }
            DispatchQueue.main.async {
                guard let self, self.workspaceScanSession?.id == sessionID else { return }
                self.workspaceScanSession?.results = results
                self.workspaceScanSession?.phase = .review
            }
        }
    }

    func dismissWorkspaceScan() {
        guard workspaceScanSession?.phase != .importing else { return }
        workspaceScanSession = nil
    }

    func toggleScanResult(_ id: String) {
        guard let i = workspaceScanSession?.results.firstIndex(where: { $0.id == id }) else { return }
        workspaceScanSession?.results[i].isSelected.toggle()
    }

    /// 全选/取消全选。传 visibleIDs 时只作用于当前搜索可见项（隐藏项勾选态保持不变）。
    func selectAllScanResults(_ select: Bool, visibleIDs: Set<String>? = nil) {
        guard var session = workspaceScanSession else { return }
        for i in session.results.indices {
            if let visibleIDs, !visibleIDs.contains(session.results[i].id) { continue }
            session.results[i].isSelected = select
        }
        workspaceScanSession = session
    }

    /// 把勾选的文件夹逐个原位登记为独立编码空间（名称=文件夹名，只写入
    /// .gojo 清单，不移动、不复制原文件）。
    func importScannedWorkspaces() {
        guard let session = workspaceScanSession else { return }
        let targets = session.selectedForImport
        guard !targets.isEmpty else { return }
        let sessionID = session.id
        workspaceScanSession?.phase = .importing
        let manager = self.manager

        asyncQueue.async { [weak self] in
            for result in targets {
                DispatchQueue.main.async {
                    self?.updateScanResult(result.id, in: sessionID, status: .registering)
                }
                do {
                    guard FileManager.default.fileExists(atPath: result.project.url.path) else {
                        throw WorkspaceError.codingSpaceFolderMissing(result.project.name)
                    }
                    try manager.createCodingSpace(name: result.project.name, at: result.project.url)
                    DispatchQueue.main.async {
                        self?.updateScanResult(result.id, in: sessionID, status: .registered)
                    }
                } catch {
                    let msg = "\(error)"
                    DispatchQueue.main.async {
                        self?.updateScanResult(result.id, in: sessionID, status: .failed(msg))
                    }
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if self.workspaceScanSession?.id == sessionID {
                    self.workspaceScanSession?.phase = .finished
                }
                self.reload()
            }
        }
    }

    private func updateScanResult(_ id: String, in sessionID: UUID,
                                  status: WorkspaceScanResultStatus) {
        guard workspaceScanSession?.id == sessionID,
              let i = workspaceScanSession?.results.firstIndex(where: { $0.id == id })
        else { return }
        workspaceScanSession?.results[i].status = status
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

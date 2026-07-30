import AppKit
import Foundation
import GojoCore

@MainActor
final class AppState: ObservableObject {
    @Published var publicProjects: [PublicProject] = []
    @Published var codingSpaces: [URL] = []
    @Published var membersByPath: [String: [ScannedMember]] = [:]
    @Published var route: Route = .shelf
    @Published var busyMembers: Set<String> = []
    @Published var errorMessage: String?

    let manager: WorkspaceManager
    let store: ConfigStore
    private let launcher = ExternalAppLauncher()
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
    func runAsync(space: URL, folder: String, _ work: @escaping () throws -> Void) {
        let key = busyKey(space: space, folder: folder)
        guard !busyMembers.contains(key) else { return }
        busyMembers.insert(key)
        asyncQueue.async { [weak self] in
            do {
                try work()
                DispatchQueue.main.async { self?.busyMembers.remove(key); self?.reload() }
            } catch {
                DispatchQueue.main.async {
                    self?.busyMembers.remove(key)
                    self?.errorMessage = "\(error)"
                    self?.reload()
                }
            }
        }
    }

    func members(in space: URL) -> [ScannedMember] {
        membersByPath[space.path] ?? []
    }

    var publicSpaceFolder: URL? { try? manager.publicSpaceURL() }

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

    // MARK: 编码空间
    func createCodingSpace() {
        guard let url = pickFolder(message: "选择/新建编码空间文件夹") else { return }
        run { try manager.createCodingSpace(name: url.lastPathComponent, at: url) }
    }
    func addPublicToSpace(_ space: URL, projectId: UUID, mode: MemberMode) {
        let folder = publicProjects.first(where: { $0.id == projectId })?.name ?? projectId.uuidString
        let manager = self.manager
        switch mode {
        case .git:
            runAsync(space: space, folder: folder) {
                try manager.addPublicProjectToSpace(projectId: projectId, mode: .git, in: space)
            }
        case .symlink:
            run { try manager.addPublicProjectToSpace(projectId: projectId, mode: .symlink, in: space) }
        }
    }
    func moveMember(_ folderName: String, from source: URL, to dest: URL) {
        guard source != dest else { return }
        let manager = self.manager
        runAsync(space: source, folder: folderName) {
            try manager.moveMember(folderName: folderName, from: source, to: dest)
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

import AppKit
import Foundation
import GojoCore

enum SidebarSelection: Hashable {
    case publicSpace
    case codingSpace(URL)
    case devProject(space: URL, project: URL)
}

@MainActor
final class AppState: ObservableObject {
    @Published var publicRepos: [URL] = []
    @Published var codingSpaces: [URL] = []
    @Published var errorMessage: String?
    @Published var selection: SidebarSelection?

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
        publicRepos = (try? manager.publicRepos()) ?? []
    }

    func run(_ action: () throws -> Void) {
        do { try action(); reload() }
        catch { errorMessage = "\(error)" }
    }

    func devProjects(in space: URL) -> [URL] {
        let ws = try? store.loadWorkspace(at: space)
        return (ws?.projectDirectories ?? []).map { space.appendingPathComponent($0) }
    }

    func projectManifest(at project: URL) -> ProjectManifest? {
        try? store.loadProject(at: project)
    }

    var terminalPreference: TerminalApp {
        get { store.loadIndex().terminalPreference }
        set { var i = store.loadIndex(); i.terminalPreference = newValue; try? store.saveIndex(i) }
    }

    /// 当前选中项对应的文件夹（用于终端/访达定位）。
    var selectedFolderURL: URL? {
        switch selection {
        case .publicSpace: return try? manager.publicSpaceURL()
        case .codingSpace(let u): return u
        case .devProject(_, let p): return p
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

    /// 用 NSOpenPanel 选文件夹（同步返回）。
    func pickFolder(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = message
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseAndSetPublicSpace() {
        guard let url = pickFolder(message: "选择公共空间文件夹") else { return }
        run { try manager.setPublicSpace(url) }
    }

    func addPublicRepo(url: String) { run { try manager.addPublicRepo(url: url) } }

    func createCodingSpace() {
        guard let url = pickFolder(message: "选择/新建编码空间文件夹") else { return }
        run { try manager.createCodingSpace(name: url.lastPathComponent, at: url) }
    }

    func createDevProject(named name: String, in space: URL) {
        run { _ = try manager.createDevProject(name: name, in: space, existingFolder: nil) }
    }

    func adoptExistingProject(in space: URL) {
        guard let folder = pickFolder(message: "指认已存在文件夹为开发项目") else { return }
        run { _ = try manager.createDevProject(name: folder.lastPathComponent, in: space, existingFolder: folder) }
    }

    func addRepoToProject(_ project: URL, url: String, subdir: String) {
        run { try manager.addRepo(url: url, subdirectory: subdir, to: project) }
    }

    func addSymlinkToProject(_ project: URL, publicRepo: String, linkName: String) {
        run { try manager.addSymlink(publicRepoName: publicRepo, linkName: linkName, in: project) }
    }

    func syncRepo(_ project: URL, subdir: String) {
        run { try manager.syncRepo(subdir: subdir, in: project) }
    }

    func setBranch(_ project: URL, subdir: String, branch: String) {
        run { try manager.setBranch(branch, repoSubdir: subdir, in: project) }
    }
}

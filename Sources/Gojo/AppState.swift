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
    func moveMember(_ folderName: String, from source: URL, to dest: URL) {
        guard source != dest else { return }
        run { try manager.moveMember(folderName: folderName, from: source, to: dest) }
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

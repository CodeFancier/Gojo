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
}

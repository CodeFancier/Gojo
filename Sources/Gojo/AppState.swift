import Foundation
import GojoCore

@MainActor
final class AppState: ObservableObject {
    @Published var publicRepos: [URL] = []
    @Published var codingSpaces: [URL] = []
    @Published var errorMessage: String?

    let manager: WorkspaceManager
    private let store: ConfigStore

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
}

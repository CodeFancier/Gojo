import Foundation

public struct ProjectManifest: Codable, Equatable {
    public var name: String
    public var repos: [GitRepoBinding]
    public var symlinks: [SymlinkBinding]

    public init(name: String, repos: [GitRepoBinding] = [], symlinks: [SymlinkBinding] = []) {
        self.name = name
        self.repos = repos
        self.symlinks = symlinks
    }
}

import Foundation

public struct ConfigStore {
    private let baseDirectory: URL
    private let fm = FileManager.default

    /// baseDirectory 缺省为 ~/Library/Application Support/Gojo，可注入以便测试。
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

import Foundation

public enum WorkspaceError: Error, Equatable {
    case noPublicSpace
    case publicRepoNotFound(String)
    case invalidGitURL(String)
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

    // MARK: 公共空间
    public func setPublicSpace(_ url: URL) throws {
        var index = store.loadIndex()
        index.publicSpacePath = url.path
        try store.saveIndex(index)
    }

    public func publicSpaceURL() throws -> URL {
        guard let p = store.loadIndex().publicSpacePath else { throw WorkspaceError.noPublicSpace }
        return URL(fileURLWithPath: p)
    }

    public func addPublicRepo(url: String) throws {
        let base = try publicSpaceURL()
        let name = Self.repoFolderName(from: url)
        try git.clone(url: url, into: base.appendingPathComponent(name))
    }

    public func publicRepos() throws -> [URL] {
        let base = try publicSpaceURL()
        let entries = (try? fm.contentsOfDirectory(at: base,
            includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return entries.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
                      .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: 编码空间
    public func createCodingSpace(name: String, at url: URL) throws {
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try store.saveWorkspace(WorkspaceManifest(name: name), at: url)
        var index = store.loadIndex()
        if !index.codingSpacePaths.contains(url.path) { index.codingSpacePaths.append(url.path) }
        try store.saveIndex(index)
    }

    // MARK: 开发项目
    /// existingFolder 非空 → 指认已存在文件夹；为空 → 在编码空间下新建同名子文件夹。
    @discardableResult
    public func createDevProject(name: String, in codingSpace: URL,
                                 existingFolder: URL?) throws -> URL {
        let root = existingFolder ?? codingSpace.appendingPathComponent(name)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try store.saveProject(ProjectManifest(name: name), at: root)

        var ws = (try store.loadWorkspace(at: codingSpace)) ?? WorkspaceManifest(name: name)
        let rel = root.lastPathComponent
        if !ws.projectDirectories.contains(rel) { ws.projectDirectories.append(rel) }
        try store.saveWorkspace(ws, at: codingSpace)
        return root
    }

    public func addRepo(url: String, subdirectory: String, to project: URL) throws {
        let dest = project.appendingPathComponent(subdirectory)
        try git.clone(url: url, into: dest)
        let branch = try? git.currentBranch(at: dest)
        var m = (try store.loadProject(at: project)) ?? ProjectManifest(name: project.lastPathComponent)
        m.repos.append(GitRepoBinding(url: url, subdirectory: subdirectory, branch: branch))
        try store.saveProject(m, at: project)
    }

    public func setBranch(_ branch: String, repoSubdir: String, in project: URL) throws {
        try git.checkout(branch: branch, at: project.appendingPathComponent(repoSubdir))
        var m = (try store.loadProject(at: project)) ?? ProjectManifest(name: project.lastPathComponent)
        if let i = m.repos.firstIndex(where: { $0.subdirectory == repoSubdir }) {
            m.repos[i].branch = branch
            try store.saveProject(m, at: project)
        }
    }

    public func syncRepo(subdir: String, in project: URL) throws {
        try git.pull(at: project.appendingPathComponent(subdir))
    }

    public func addSymlink(publicRepoName: String, linkName: String, in project: URL) throws {
        let target = try publicSpaceURL().appendingPathComponent(publicRepoName)
        guard fm.fileExists(atPath: target.path) else {
            throw WorkspaceError.publicRepoNotFound(publicRepoName)
        }
        try symlink.createSymlink(at: project.appendingPathComponent(linkName), pointingTo: target)
        var m = (try store.loadProject(at: project)) ?? ProjectManifest(name: project.lastPathComponent)
        m.symlinks.append(SymlinkBinding(publicRepoName: publicRepoName, linkPath: linkName))
        try store.saveProject(m, at: project)
    }

    // 从 git URL 推导默认文件夹名：去掉 .git 后缀取末段。
    static func repoFolderName(from url: String) -> String {
        var s = url
        if s.hasSuffix(".git") { s.removeLast(4) }
        let last = s.split(whereSeparator: { $0 == "/" || $0 == ":" }).last.map(String.init) ?? "repo"
        return last.isEmpty ? "repo" : last
    }
}

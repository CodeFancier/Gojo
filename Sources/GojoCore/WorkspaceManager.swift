import Foundation

public enum WorkspaceError: Error, Equatable {
    case noPublicSpace
    case publicProjectNotFound(UUID)
    case publicProjectNotCloned(String)
    case memberNotFound(String)
    case notASymlinkMember(String)
    case notAGitMember(String)
    case memberNameCollision(String)
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

    /// 把成员整体从一个编码空间移动到另一个。standalone / git / symlink 统一处理：
    /// moveItem 迁移文件夹或符号链接本身（绝对路径符号链接移动后仍可解析），
    /// 若有清单绑定则一并迁移。无损、可逆（挪回即还原）。
    public func moveMember(folderName: String, from source: URL, to dest: URL) throws {
        let srcPath = source.appendingPathComponent(folderName)
        let destPath = dest.appendingPathComponent(folderName)
        guard !fm.fileExists(atPath: destPath.path) else {
            throw WorkspaceError.memberNameCollision(folderName)
        }

        var srcManifest = (try store.loadWorkspace(at: source))
            ?? WorkspaceManifest(name: source.lastPathComponent)
        let bound = srcManifest.members.first { $0.folderName == folderName }

        try fm.moveItem(at: srcPath, to: destPath)

        guard let bound else { return }        // standalone：无绑定，仅移动文件夹
        srcManifest.members.removeAll { $0.folderName == folderName }
        try store.saveWorkspace(srcManifest, at: source)
        var destManifest = (try store.loadWorkspace(at: dest))
            ?? WorkspaceManifest(name: dest.lastPathComponent)
        destManifest.members.removeAll { $0.folderName == folderName }
        destManifest.members.append(bound)
        try store.saveWorkspace(destManifest, at: dest)
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

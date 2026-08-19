import Foundation

public enum WorkspaceError: Error, Equatable {
    case noPublicSpace
    case publicProjectNotFound(UUID)
    case publicProjectNotCloned(String)
    case memberNotFound(String)
    case notASymlinkMember(String)
    case notAGitMember(String)
    case memberNameCollision(String)
    case publicProjectNameCollision(String)
    case publicProjectInUse(String)
    case unsafePublicProjectPath(String)
    case nestedPublicProjectNotFound(String)
    case codingSpaceNotFound(String)
    case unsafeCodingSpacePath(String)
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
        try git.clone(url: proj.url, into: space.appendingPathComponent(proj.localRelativePath))
        m.projects[i].cloned = true
        try store.savePublicSpace(m, at: space)
    }

    /// 删除公共项目。仍被编码空间引用时拒绝操作；本地仓库移入废纸篓后再移除定义。
    public func removePublicProject(id: UUID) throws {
        let space = try publicSpaceURL()
        var manifest = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        guard let project = manifest.projects.first(where: { $0.id == id }) else {
            throw WorkspaceError.publicProjectNotFound(id)
        }

        for codingSpace in codingSpaceURLs() {
            let workspace = try store.loadWorkspace(at: codingSpace)
            if workspace?.members.contains(where: { $0.publicProjectId == id }) == true {
                throw WorkspaceError.publicProjectInUse(project.name)
            }
        }

        let projectURL = space
            .appendingPathComponent(project.localRelativePath)
            .standardizedFileURL
        try validatePublicProjectPath(projectURL, in: space)
        if itemExists(at: projectURL) {
            try fm.trashItem(at: projectURL, resultingItemURL: nil)
        }

        manifest.projects.removeAll { $0.id == id }
        try store.savePublicSpace(manifest, at: space)
    }

    /// 合并清单与扫描：刷新 cloned 标志，补录扫描到但清单缺失的库；持久化后返回。
    public func publicProjects() throws -> [PublicProject] {
        let space = try publicSpaceURL()
        var m = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()

        // 1) 刷新已有项的 cloned 状态
        for i in m.projects.indices {
            let path = space.appendingPathComponent(m.projects[i].localRelativePath).path
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

    /// 扫描公共空间中所有可展开目录，以及其中直接包含的 Git 子项目。
    /// 已登记且已落盘的公共项目即使没有子项目，也会作为可展开目录返回。
    public func publicCompositeFolders() throws -> [PublicCompositeFolder] {
        let space = try publicSpaceURL()
        let manifest = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        var registeredByPath: [String: UUID] = [:]
        for project in manifest.projects {
            registeredByPath[project.localRelativePath] = project.id
        }

        var candidates: [String: URL] = [:]
        for folder in directoryEntries(at: space) where folder.lastPathComponent != ".gojo" {
            candidates[folder.lastPathComponent] = folder
        }
        for project in manifest.projects {
            let path = project.localRelativePath
            let folder = space.appendingPathComponent(path)
            if fm.fileExists(atPath: folder.path) {
                candidates[path] = folder
            }
        }

        return candidates.compactMap { relativePath, folder in
            let projects = directoryEntries(at: folder).compactMap { child -> NestedPublicProject? in
                guard fm.fileExists(atPath: child.appendingPathComponent(".git").path) else {
                    return nil
                }
                let name = child.lastPathComponent
                let childRelativePath = "\(relativePath)/\(name)"
                return NestedPublicProject(
                    parentRelativePath: relativePath,
                    name: name,
                    url: (try? git.remoteURL(at: child)) ?? "",
                    publicProjectID: registeredByPath[childRelativePath]
                )
            }
            let publicProjectID = registeredByPath[relativePath]
            guard publicProjectID != nil || !projects.isEmpty else { return nil }
            return PublicCompositeFolder(
                name: folder.lastPathComponent,
                relativePath: relativePath,
                publicProjectID: publicProjectID,
                projects: projects
            )
        }
        .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    /// 将嵌套仓库登记为公共项目。仓库保留原位，通过 relativePath 参与后续软链接和状态扫描。
    public func promoteNestedPublicProject(parentRelativePath: String,
                                           projectName: String) throws {
        let relativePath = "\(parentRelativePath)/\(projectName)"
        guard let nested = try publicCompositeFolders()
            .first(where: { $0.relativePath == parentRelativePath })?
            .projects.first(where: { $0.name == projectName }) else {
            throw WorkspaceError.nestedPublicProjectNotFound(relativePath)
        }

        let space = try publicSpaceURL()
        var manifest = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        if manifest.projects.contains(where: { $0.localRelativePath == relativePath }) {
            return
        }
        guard !manifest.projects.contains(where: { $0.name == projectName }) else {
            throw WorkspaceError.publicProjectNameCollision(projectName)
        }
        manifest.projects.append(PublicProject(name: projectName, url: nested.url, cloned: true,
                                               relativePath: relativePath))
        try store.savePublicSpace(manifest, at: space)
    }

    public func promoteNestedPublicProject(parentFolderName: String,
                                           projectName: String) throws {
        try promoteNestedPublicProject(
            parentRelativePath: parentFolderName, projectName: projectName)
    }

    // MARK: - 编码空间根目录

    /// 指定/更新编码空间根目录；之后新建空间默认创建在其下。
    public func setCodingSpaceRoot(_ url: URL) throws {
        var index = store.loadIndex()
        index.codingSpaceRootPath = url.path
        try store.saveIndex(index)
    }

    /// 清除编码空间根目录；已登记的空间不受影响。
    public func clearCodingSpaceRoot() throws {
        var index = store.loadIndex()
        index.codingSpaceRootPath = nil
        try store.saveIndex(index)
    }

    public func codingSpaceRootURL() -> URL? {
        store.loadIndex().codingSpaceRootPath.map(URL.init(fileURLWithPath:))
    }

    /// 计算目录下不冲突的文件夹名：与磁盘已有项或 usedNames 重名时追加 _2/_3。
    /// 与扫描导入的内联去重约定一致（fileExists 对同名文件与目录都成立）。
    public static func uniqueCodingSpaceFolderName(base: String,
                                                   in directory: URL,
                                                   usedNames: Set<String> = []) -> String {
        var name = base
        var suffix = 2
        while usedNames.contains(name)
                || FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent(name).path) {
            name = "\(base)_\(suffix)"
            suffix += 1
        }
        return name
    }

    /// 清洗用户输入的空间名：去首尾空白、替换路径分隔符与冒号、去掉前导点（防隐藏目录）。
    /// 清洗后可能为空串，由调用方据此禁用确认操作。
    public static func sanitizedFolderName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        while name.hasPrefix(".") { name.removeFirst() }
        return name
    }

    /// 在根目录下创建编码空间（重名自动 _2/_3），返回实际创建的空间 URL。
    /// 清单名沿用「名称 = 文件夹名」的既有约定（同 NSOpenPanel 流程）。
    @discardableResult
    public func createCodingSpace(named name: String, underRoot root: URL) throws -> URL {
        let folder = Self.uniqueCodingSpaceFolderName(base: name, in: root)
        let url = root.appendingPathComponent(folder)
        try createCodingSpace(name: folder, at: url)
        return url
    }

    // MARK: - 编码空间

    public func createCodingSpace(name: String, at url: URL) throws {
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try store.saveWorkspace(WorkspaceManifest(name: name), at: url)
        var index = store.loadIndex()
        if !index.codingSpacePaths.contains(url.path) { index.codingSpacePaths.append(url.path) }
        try store.saveIndex(index)
    }

    public func codingSpaceURLs() -> [URL] {
        store.loadIndex().codingSpacePaths.map(URL.init(fileURLWithPath:))
    }

    /// 从 Gojo 移除编码空间，并按选择决定是否同时清理磁盘内容。
    public func removeCodingSpace(at codingSpace: URL,
                                  mode: CodingSpaceRemovalMode) throws {
        let normalizedSpace = codingSpace.standardizedFileURL
        let normalizedPath = normalizedSpace.path
        var index = store.loadIndex()
        guard index.codingSpacePaths.contains(where: {
            URL(fileURLWithPath: $0).standardizedFileURL.path == normalizedPath
        }) else {
            throw WorkspaceError.codingSpaceNotFound(codingSpace.path)
        }

        switch mode {
        case .unregisterOnly:
            break
        case .contents:
            try validateDestructiveCodingSpace(normalizedSpace)
            if itemExists(at: normalizedSpace) {
                let entries = try fm.contentsOfDirectory(
                    at: normalizedSpace, includingPropertiesForKeys: nil)
                for entry in entries {
                    try fm.removeItem(at: entry)
                }
            }
        case .directory:
            try validateDestructiveCodingSpace(normalizedSpace)
            if itemExists(at: normalizedSpace) {
                try fm.removeItem(at: normalizedSpace)
            }
        }

        index.codingSpacePaths.removeAll {
            URL(fileURLWithPath: $0).standardizedFileURL.path == normalizedPath
        }
        try store.saveIndex(index)
    }

    /// 返回删除任务顺序：先列出直接子文件夹，最后是编码空间根文件夹。
    public func codingSpaceRemovalItems(at codingSpace: URL) throws -> [CodingSpaceRemovalItem] {
        let normalizedSpace = codingSpace.standardizedFileURL
        try validateDestructiveCodingSpace(normalizedSpace)
        guard itemExists(at: normalizedSpace) else { return [] }
        let entries = try fm.contentsOfDirectory(
            at: normalizedSpace,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )
        let children = entries.compactMap { entry -> CodingSpaceRemovalItem? in
            guard entry.lastPathComponent != ".gojo" else { return nil }
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true || values?.isSymbolicLink == true else { return nil }
            return CodingSpaceRemovalItem(name: entry.lastPathComponent, url: entry, isRoot: false)
        }
        .sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return children + [CodingSpaceRemovalItem(
            name: normalizedSpace.lastPathComponent, url: normalizedSpace, isRoot: true)]
    }

    /// 将单个删除任务移入 macOS 废纸篓。子项目只能是编码空间的直接子级。
    public func moveCodingSpaceRemovalItemToTrash(_ item: CodingSpaceRemovalItem,
                                                   in codingSpace: URL) throws {
        let normalizedSpace = codingSpace.standardizedFileURL
        try validateDestructiveCodingSpace(normalizedSpace)
        let itemURL = item.url.standardizedFileURL
        let isRoot = item.isRoot && itemURL.path == normalizedSpace.path
        let isDirectChild = !item.isRoot
            && itemURL.deletingLastPathComponent().path == normalizedSpace.path
            && itemURL.lastPathComponent != ".gojo"
        guard isRoot || isDirectChild else {
            throw WorkspaceError.unsafeCodingSpacePath(item.url.path)
        }
        // 删除确认后，文件仍可能被用户或其他进程先一步移走。此时目标状态已经达成。
        guard itemExists(at: itemURL) else { return }
        try fm.trashItem(at: itemURL, resultingItemURL: nil)
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
                if let b = bound, b.mode == .symlink {
                    form = .publicSymlink(b.publicProjectId)
                } else if let target = resolvedSymlinkTarget(entry),
                          fm.fileExists(atPath: target.appendingPathComponent(".git").path) {
                    // 未绑定、但指向外部含 .git 仓库的符号链接（如一键扫描导入的成员）
                    form = .externalSymlink(target.path)
                } else {
                    continue   // 其余未知符号链接，跳过
                }
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

    /// 把外部项目目录以符号链接形式加入编码空间。不写清单——靠 `scanMembers` 发现为
    /// `.externalSymlink`，与独立仓库（standalone）同为「不入清单、扫描发现」的成员形态。
    public func linkExternalProject(into codingSpace: URL, folderName: String, target: URL) throws {
        let dest = codingSpace.appendingPathComponent(folderName)
        guard !itemExists(at: dest) else { throw WorkspaceError.memberNameCollision(folderName) }
        try symlink.createSymlink(at: dest, pointingTo: target)
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
            try symlink.createSymlink(
                at: dest, pointingTo: space.appendingPathComponent(proj.localRelativePath))
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

    /// 删除编码空间中的一个直接成员。普通目录会递归清理；符号链接只删除链接本身。
    public func removeMember(folderName: String, in codingSpace: URL) throws {
        let path = codingSpace.appendingPathComponent(folderName)
        guard isDirectChild(path, of: codingSpace), itemExists(at: path) else {
            throw WorkspaceError.memberNotFound(folderName)
        }

        try fm.removeItem(at: path)
        var manifest = (try store.loadWorkspace(at: codingSpace))
            ?? WorkspaceManifest(name: codingSpace.lastPathComponent)
        manifest.members.removeAll { $0.folderName == folderName }
        try store.saveWorkspace(manifest, at: codingSpace)
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
        try symlink.createSymlink(
            at: dest, pointingTo: space.appendingPathComponent(proj.localRelativePath))
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

    private func directoryEntries(at url: URL) -> [URL] {
        ((try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? [])
            .filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    /// 解析符号链接的目标为绝对 URL（相对目标按链接所在目录解析），不跟踪后续链。
    private func resolvedSymlinkTarget(_ linkURL: URL) -> URL? {
        guard let dest = try? fm.destinationOfSymbolicLink(atPath: linkURL.path) else { return nil }
        return dest.hasPrefix("/")
            ? URL(fileURLWithPath: dest)
            : linkURL.deletingLastPathComponent().appendingPathComponent(dest)
    }

    private func isDirectChild(_ child: URL, of parent: URL) -> Bool {
        child.standardizedFileURL.deletingLastPathComponent() == parent.standardizedFileURL
    }

    private func itemExists(at url: URL) -> Bool {
        (try? fm.attributesOfItem(atPath: url.path)) != nil
    }

    private func validateDestructiveCodingSpace(_ codingSpace: URL) throws {
        let root = URL(fileURLWithPath: "/").standardizedFileURL
        let home = fm.homeDirectoryForCurrentUser.standardizedFileURL
        let isRegistered = store.loadIndex().codingSpacePaths.contains {
            URL(fileURLWithPath: $0).standardizedFileURL == codingSpace
        }
        guard codingSpace != root, codingSpace != home,
              isRegistered else {
            throw WorkspaceError.unsafeCodingSpacePath(codingSpace.path)
        }
    }

    private func validatePublicProjectPath(_ project: URL, in publicSpace: URL) throws {
        let root = publicSpace.standardizedFileURL
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let relativePath = String(project.path.dropFirst(rootPrefix.count))
        guard project.path.hasPrefix(rootPrefix),
              project != root,
              !relativePath.isEmpty,
              relativePath.split(separator: "/").first != ".gojo" else {
            throw WorkspaceError.unsafePublicProjectPath(project.path)
        }
    }

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

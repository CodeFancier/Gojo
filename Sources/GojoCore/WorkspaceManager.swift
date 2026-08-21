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
    case codingSpaceFolderMissing(String)
    case unsafeCodingSpacePath(String)
    case invalidCodingSpaceName
    case codingSpaceNameCollision(String)
}

public final class WorkspaceManager {
    private let store: ConfigStore
    private let git: GitService
    private let symlink: SymlinkService
    private let renamer: CodingSpaceRenamer
    private let fm = FileManager.default

    public init(configStore: ConfigStore,
                git: GitService = GitService(),
                symlink: SymlinkService = SymlinkService()) {
        self.store = configStore
        self.git = git
        self.symlink = symlink
        self.renamer = CodingSpaceRenamer(configStore: configStore)
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
            try trash(at: projectURL)
        }

        manifest.projects.removeAll { $0.id == id }
        try store.savePublicSpace(manifest, at: space)
    }

    /// 刷新清单各项的 cloned 标志并持久化。不做扫描补录——顶层 Git 目录须显式
    /// 「转为公共仓库」（promotePublicProject）才入清单；磁盘=事实，登记=语义。
    public func publicProjects() throws -> [PublicProject] {
        let space = try publicSpaceURL()
        var m = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        for i in m.projects.indices {
            let path = space.appendingPathComponent(m.projects[i].localRelativePath).path
            m.projects[i].cloned = fm.fileExists(atPath: path)
        }
        try store.savePublicSpace(m, at: space)
        return m.projects.sorted { $0.name < $1.name }
    }

    /// 列出公共空间的全部条目：根下所有直接子目录 ∪ 清单全部登记项（含未落盘）。
    /// 每个条目都可展开扫描直接子级 Git 仓库；登记项本身（含嵌套路径）也有独立条目。
    public func publicSpaceEntries() throws -> [PublicSpaceEntry] {
        let space = try publicSpaceURL()
        let manifest = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        var registeredByPath: [String: UUID] = [:]
        for project in manifest.projects {
            registeredByPath[project.localRelativePath] = project.id
        }

        // 候选 = 根下全部直接子目录（排除 .gojo）∪ 清单登记项；nil 表示登记但未落盘。
        var candidates: [String: URL?] = [:]
        for folder in directoryEntries(at: space) where folder.lastPathComponent != ".gojo" {
            candidates[folder.lastPathComponent] = folder
        }
        for project in manifest.projects where candidates[project.localRelativePath] == nil {
            let folder = space.appendingPathComponent(project.localRelativePath)
            candidates[project.localRelativePath] =
                fm.fileExists(atPath: folder.path) ? folder : nil
        }

        return candidates.map { relativePath, folder -> PublicSpaceEntry in
            guard let folder else {
                // 未落盘的登记项：保留 Clone / 删除入口。登记嵌套路径的目录被手动
                // 删除后也落到这里，Clone 会落回原嵌套路径（git clone 自建父目录）。
                let name = manifest.projects
                    .first { $0.localRelativePath == relativePath }?.name ?? relativePath
                return PublicSpaceEntry(
                    name: name, relativePath: relativePath, isOnDisk: false,
                    publicProjectID: registeredByPath[relativePath]
                )
            }
            let isGit = fm.fileExists(atPath: folder.appendingPathComponent(".git").path)
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
            return PublicSpaceEntry(
                name: folder.lastPathComponent,
                relativePath: relativePath,
                isOnDisk: true,
                isGitRepository: isGit,
                remoteURL: isGit ? ((try? git.remoteURL(at: folder)) ?? "") : "",
                publicProjectID: registeredByPath[relativePath],
                projects: projects
            )
        }
        .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    /// 将公共空间内的某个 Git 仓库原位登记为公共项目。适用顶层目录自身或任一条目的
    /// 直接子级；仓库保留原位，通过 relativePath 参与后续软链接和状态扫描。
    public func promotePublicProject(relativePath: String) throws {
        guard let url = try promotableRepoURL(relativePath: relativePath) else {
            throw WorkspaceError.nestedPublicProjectNotFound(relativePath)
        }

        let space = try publicSpaceURL()
        var manifest = (try store.loadPublicSpace(at: space)) ?? PublicSpaceManifest()
        if manifest.projects.contains(where: { $0.localRelativePath == relativePath }) {
            return
        }
        let name = URL(fileURLWithPath: relativePath).lastPathComponent
        guard !manifest.projects.contains(where: { $0.name == name }) else {
            throw WorkspaceError.publicProjectNameCollision(name)
        }
        manifest.projects.append(PublicProject(name: name, url: url, cloned: true,
                                               relativePath: relativePath))
        try store.savePublicSpace(manifest, at: space)
    }

    /// 在条目树中解析 relativePath 对应的仓库远程地址；找不到或非 Git 仓库返回 nil。
    private func promotableRepoURL(relativePath: String) throws -> String? {
        for entry in try publicSpaceEntries() {
            if entry.relativePath == relativePath {
                return entry.isGitRepository ? entry.remoteURL : nil
            }
            if let child = entry.projects.first(where: { $0.id == relativePath }) {
                return child.url
            }
        }
        return nil
    }

    /// 将嵌套仓库登记为公共项目。仓库保留原位，通过 relativePath 参与后续软链接和状态扫描。
    public func promoteNestedPublicProject(parentRelativePath: String,
                                           projectName: String) throws {
        try promotePublicProject(relativePath: "\(parentRelativePath)/\(projectName)")
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

    /// 列出根目录下可登记为编码空间的已存在文件夹：非隐藏、未登记的直接子目录。
    /// 不筛 .git——编码空间成员本就允许非 git 项目，登记门槛保持一致。
    public func existingProjectFolders(underRoot root: URL) throws -> [ExistingProjectFolder] {
        let registered = Set(store.loadIndex().codingSpacePaths.map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        })
        let entries = (try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        return entries.compactMap { entry -> ExistingProjectFolder? in
            guard entry.lastPathComponent != ".gojo" else { return nil }
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  !registered.contains(entry.standardizedFileURL.path) else { return nil }
            return ExistingProjectFolder(
                url: entry,
                isGitRepository: fm.fileExists(atPath: entry.appendingPathComponent(".git").path))
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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

    // MARK: - 编码空间重命名

    /// 重命名 dry-run：清洗名称、算新 URL、统计旧路径下要转载的 agent 记忆。
    public func planCodingSpaceRename(at space: URL,
                                      to rawName: String) throws -> CodingSpaceRenamePlan {
        try renamer.planRename(of: space, to: rawName)
    }

    /// 重命名编码空间（名称=文件夹名）：移动目录、更新登记与清单名；
    /// migrateMemory 时把 agent 挂在旧路径的记忆一并转载（失败项见 outcome，
    /// 可对 outcome 的 old/new URL 幂等重试）。
    public func renameCodingSpace(at space: URL, to rawName: String,
                                  migrateMemory: Bool) throws -> CodingSpaceRenameOutcome {
        try renamer.rename(space, to: rawName, migrateMemory: migrateMemory)
    }

    /// 转载失败后的幂等重试（重命名已完成）。
    public func retryCodingSpaceMemoryMigration(from oldSpace: URL,
                                                to newSpace: URL) -> [AgentMigrationItemResult] {
        renamer.retryMigration(from: oldSpace, to: newSpace)
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
        try trash(at: itemURL)
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
                          isExistingDirectory(target) {
                    // 未绑定、指向外部现存目录的符号链接（如一键扫描导入的成员）。
                    // 不要求目标含 .git：Claude/Codex 项目常非 git 仓库，导入端
                    // （linkExternalProject）同样不设此门槛，两端必须一致，否则
                    // 导入“成功”后成员被扫描悄悄过滤，空间沦为空壳。
                    form = .externalSymlink(target.path)
                } else {
                    continue   // 失效链接或指向非目录，跳过
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

    /// 目标是否为磁盘上现存的目录（fileExists 对失效链接返回 false，天然过滤）。
    private func isExistingDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func isDirectChild(_ child: URL, of parent: URL) -> Bool {
        child.standardizedFileURL.deletingLastPathComponent() == parent.standardizedFileURL
    }

    private func itemExists(at url: URL) -> Bool {
        (try? fm.attributesOfItem(atPath: url.path)) != nil
    }

    /// macOS 移入废纸篓；Linux 的 corelibs-foundation 无 trashItem，退化为直接删除
    /// （仅影响 Linux 上的本地验证构建，产品只发 macOS）。
    private func trash(at url: URL) throws {
        #if os(macOS)
        try fm.trashItem(at: url, resultingItemURL: nil)
        #else
        try fm.removeItem(at: url)
        #endif
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

import Foundation

/// 编码空间重命名编排。「名称 = 文件夹名」约定下，改名 = 移动目录 + 更新登记，
/// 并（可选）把 agent 挂在旧路径下的记忆转载到新路径。
///
/// 顺序：manifest 名（旧路径原子写）→ moveItem → CentralIndex；任一步失败回滚
/// 已做的步骤。记忆迁移随后 best-effort 执行——失败逐项报告、可幂等重试，
/// 不回滚重命名（Gojo 自身状态是可控原子单元，外部记忆靠幂等兜底）。
public final class CodingSpaceRenamer: @unchecked Sendable {
    private let store: ConfigStore
    private let migration: AgentMemoryMigrationService
    private let fm = FileManager.default

    public init(configStore: ConfigStore,
                home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.store = configStore
        self.migration = AgentMemoryMigrationService(home: home)
    }

    // MARK: dry-run

    /// 预检：清洗名称、算新 URL、统计要转载的记忆。不落任何盘。
    /// 允许与当前同名——计数只依赖旧路径侧，供 sheet 打开时就展示记忆量
    /// （同名确认由 UI 禁用，真正改名在 rename() 里再拒）。
    public func planRename(of space: URL, to rawName: String) throws -> CodingSpaceRenamePlan {
        let name = WorkspaceManager.sanitizedFolderName(rawName)
        guard !name.isEmpty else { throw WorkspaceError.invalidCodingSpaceName }
        let newURL = Self.newURL(for: space, folderName: name)
        let moves = AgentMemoryMigrationService.affectedMoves(oldSpace: space, newSpace: newURL)
        let plans = migration.plan(moves)
        return CodingSpaceRenamePlan(
            oldURL: space, newURL: newURL, sanitizedNewName: name,
            claude: plans[.claude] ?? .empty, codex: plans[.codex] ?? .empty)
    }

    // MARK: 执行

    public func rename(_ space: URL, to rawName: String, migrateMemory: Bool,
                       onProgress: (@Sendable (AgentMigrationProgress) -> Void)? = nil)
        throws -> CodingSpaceRenameOutcome {
        let name = try validatedName(rawName, currentSpace: space)
        let normalized = space.standardizedFileURL
        var index = store.loadIndex()
        guard index.codingSpacePaths.contains(where: {
            URL(fileURLWithPath: $0).standardizedFileURL.path == normalized.path
        }) else {
            throw WorkspaceError.codingSpaceNotFound(space.path)
        }
        let newURL = Self.newURL(for: normalized, folderName: name)
        guard !itemExists(at: newURL) else {
            throw WorkspaceError.codingSpaceNameCollision(name)
        }
        guard fm.fileExists(atPath: normalized.path) else {
            throw WorkspaceError.codingSpaceFolderMissing(name)
        }
        let moves = AgentMemoryMigrationService.affectedMoves(
            oldSpace: normalized, newSpace: newURL)

        // 1. manifest 名先改（仍在旧路径，原子写）——失败即止，磁盘未动。
        if var manifest = try store.loadWorkspace(at: normalized) {
            manifest.name = name
            try store.saveWorkspace(manifest, at: normalized)
        }

        // 2. 移动目录。失败恢复 manifest 名后抛出。
        do {
            try fm.moveItem(at: normalized, to: newURL)
        } catch {
            restoreManifestName(at: normalized)
            throw error
        }

        // 3. 更新登记。失败把目录挪回去、恢复 manifest 名后抛出。
        do {
            index.codingSpacePaths = index.codingSpacePaths.map {
                URL(fileURLWithPath: $0).standardizedFileURL.path == normalized.path
                    ? newURL.path : $0
            }
            try store.saveIndex(index)
        } catch {
            try? fm.moveItem(at: newURL, to: normalized)
            restoreManifestName(at: normalized)
            throw error
        }

        // 4. 记忆转载：best-effort，失败项进 outcome，不回滚重命名。
        let results = migrateMemory
            ? migration.migrate(moves, onProgress: onProgress)
            : []
        return CodingSpaceRenameOutcome(oldURL: normalized, newURL: newURL,
                                        migrationResults: results)
    }

    /// 转载失败后的幂等重试（重命名已完成，子项列表从新路径一侧取）。
    public func retryMigration(from oldSpace: URL, to newSpace: URL,
                               onProgress: (@Sendable (AgentMigrationProgress) -> Void)? = nil)
        -> [AgentMigrationItemResult] {
        migration.migrate(AgentMemoryMigrationService.affectedMoves(
            oldSpace: oldSpace.standardizedFileURL,
            newSpace: newSpace.standardizedFileURL), onProgress: onProgress)
    }

    // MARK: 私有

    private func validatedName(_ raw: String, currentSpace: URL) throws -> String {
        let name = WorkspaceManager.sanitizedFolderName(raw)
        // 空（纯空白/点号）或与当前同名都视为无效；UI 层会先禁用确认，这里兜底。
        guard !name.isEmpty, name != currentSpace.lastPathComponent else {
            throw WorkspaceError.invalidCodingSpaceName
        }
        return name
    }

    private static func newURL(for space: URL, folderName: String) -> URL {
        space.deletingLastPathComponent().appendingPathComponent(folderName)
    }

    private func itemExists(at url: URL) -> Bool {
        (try? fm.attributesOfItem(atPath: url.path)) != nil
    }

    /// 把 manifest 名恢复成目录名（名称=文件夹名约定），best-effort。
    private func restoreManifestName(at space: URL) {
        if var m = try? store.loadWorkspace(at: space) {
            m.name = space.lastPathComponent
            try? store.saveWorkspace(m, at: space)
        }
    }
}

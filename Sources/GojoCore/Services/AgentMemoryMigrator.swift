import Foundation

/// 记忆转载器：把 agent 挂在旧 cwd 下的记忆/会话迁到新 cwd。
/// 每个 agent 一个实现，适配其存储模式——Claude 按编码路径建目录（搬运目录），
/// Codex 把 cwd 写死在会话 jsonl 里（重写内容）。
public protocol AgentMemoryMigrator: Sendable {
    var kind: AgentKind { get }
    /// dry-run 计数，供重命名前 UI 提示。
    func plan(_ moves: [(old: URL, new: URL)]) -> AgentMigrationPlan
    /// 幂等执行：旧内容不存在或已迁过 = 跳过；失败逐项报告，不中断其余项。
    func migrate(_ moves: [(old: URL, new: URL)]) -> [AgentMigrationItemResult]
}

// MARK: - Claude（目录搬运）

/// Claude 的用户级记忆在 `~/.claude/projects/<编码路径>/`，路径变了目录名就变。
/// 迁移 = 把旧编码目录搬到新编码目录名下；目标已存在时逐文件合并，
/// `memory/*.md` 冲突绝不覆盖——旧的改名 `.migrated.md` 保双份
/// （Gojo 不理解记忆内容语义，只做无损搬运）。
/// - Note: `@unchecked`：FileManager 单例本身线程安全但未标 Sendable，
///   与 `AgentMemoryReader` 同一处理。
public struct ClaudeMemoryMigrator: @unchecked Sendable, AgentMemoryMigrator {
    public let kind: AgentKind = .claude
    private let home: URL
    private let fm = FileManager.default

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    private func projectDir(for path: String) -> URL {
        home.appendingPathComponent(".claude/projects", isDirectory: true)
            .appendingPathComponent(AgentMemoryReader.claudeProjectDirName(for: path),
                                    isDirectory: true)
    }

    public func plan(_ moves: [(old: URL, new: URL)]) -> AgentMigrationPlan {
        var docs = 0, sessions = 0
        for (old, new) in moves where old.path != new.path {
            let dir = projectDir(for: old.path)
            guard fm.fileExists(atPath: dir.path) else { continue }
            // 记忆文档在 memory/ 子目录；会话 jsonl 在顶层。
            let items = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            sessions += items.filter { $0.pathExtension.lowercased() == "jsonl" }.count
            let memoryDir = dir.appendingPathComponent("memory", isDirectory: true)
            let mdFiles = (try? fm.contentsOfDirectory(at: memoryDir, includingPropertiesForKeys: nil)) ?? []
            docs += mdFiles.filter { $0.pathExtension.lowercased() == "md" }.count
        }
        return AgentMigrationPlan(memoryDocs: docs, sessions: sessions)
    }

    public func migrate(_ moves: [(old: URL, new: URL)]) -> [AgentMigrationItemResult] {
        var results: [AgentMigrationItemResult] = []
        for (old, new) in moves where old.path != new.path {
            let oldDir = projectDir(for: old.path)
            let newDir = projectDir(for: new.path)
            guard fm.fileExists(atPath: oldDir.path) else { continue }
            do {
                if fm.fileExists(atPath: newDir.path) {
                    try mergeContents(of: oldDir, into: newDir, results: &results)
                } else {
                    try fm.moveItem(at: oldDir, to: newDir)
                }
            } catch {
                results.append(AgentMigrationItemResult(
                    kind: .claude, description: oldDir.lastPathComponent, error: "\(error)"))
            }
        }
        return results
    }

    /// 目标目录已存在（用户曾在同路径用过 Claude）：逐项合并，子目录递归。
    private func mergeContents(of oldDir: URL, into newDir: URL,
                               results: inout [AgentMigrationItemResult]) throws {
        let items = try fm.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil)
        for item in items {
            let dest = newDir.appendingPathComponent(item.lastPathComponent)
            var destIsDir: ObjCBool = false
            let destExists = fm.fileExists(atPath: dest.path, isDirectory: &destIsDir)
            let itemIsDir = (try? item.resourceValues(
                forKeys: [.isDirectoryKey]))?.isDirectory == true
            if !destExists {
                try fm.moveItem(at: item, to: dest)
            } else if destIsDir.boolValue && itemIsDir {
                // 子目录（如 memory/）撞名：递归合并内容。
                try mergeContents(of: item, into: dest, results: &results)
            } else if item.pathExtension.lowercased() == "md" {
                // 记忆文档冲突：旧的改名保双份，绝不覆盖目标版本。
                let renamed = uniqueMigratedSibling(of: dest)
                try fm.moveItem(at: item, to: renamed)
            } else {
                // 会话 jsonl 是 UUID 文件名，撞名几乎不可能；真撞了保留目标版本
                // （目标已含该会话，无损），静默跳过不进失败清单——重试也无解。
            }
        }
        // 旧目录搬空后清掉，避免 ~/.claude/projects 下残留失联目录迷惑用户。
        let left = (try? fm.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil)) ?? []
        if left.isEmpty { try? fm.removeItem(at: oldDir) }
    }

    /// foo.md → foo.migrated.md；已存在则 foo.migrated-2.md 依次顺延。
    private func uniqueMigratedSibling(of dest: URL) -> URL {
        let name = dest.lastPathComponent as NSString
        let base = name.deletingPathExtension
        let ext = name.pathExtension
        func join(_ tag: String) -> String {
            ext.isEmpty ? "\(base).\(tag)" : "\(base).\(tag).\(ext)"
        }
        var candidate = newDirSibling(dest, join("migrated"))
        var i = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = newDirSibling(dest, join("migrated-\(i)"))
            i += 1
        }
        return candidate
    }

    private func newDirSibling(_ dest: URL, _ fileName: String) -> URL {
        dest.deletingLastPathComponent().appendingPathComponent(fileName)
    }
}

// MARK: - Codex（内容重写）

/// Codex 的会话在 `~/.codex/sessions/**/*.jsonl`，cwd 写死在每行的
/// `payload.cwd`（session_meta / turn_context 等）。迁移 = 逐行 JSON 解析并
/// 替换旧 cwd 为新 cwd；未修改行保留原始字节，有替换才原子写回（幂等）。
public struct CodexMemoryMigrator: @unchecked Sendable, AgentMemoryMigrator {
    public let kind: AgentKind = .codex
    private let home: URL
    private let fm = FileManager.default
    /// 超大文件放弃重写并报告（极端会话；防一次性读入撑爆内存）。
    private let maxRewriteBytes = 128 * 1024 * 1024

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    private var sessionsRoot: URL {
        home.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    public func plan(_ moves: [(old: URL, new: URL)]) -> AgentMigrationPlan {
        let map = Self.pathMap(moves)
        guard !map.isEmpty else { return .empty }
        var sessions = 0
        for file in sessionFiles() {
            if let cwd = firstSessionCWD(of: file), map[cwd] != nil { sessions += 1 }
        }
        return AgentMigrationPlan(sessions: sessions)
    }

    public func migrate(_ moves: [(old: URL, new: URL)]) -> [AgentMigrationItemResult] {
        let map = Self.pathMap(moves)
        guard !map.isEmpty else { return [] }
        var results: [AgentMigrationItemResult] = []
        for file in sessionFiles() {
            guard let cwd = firstSessionCWD(of: file), let newCWD = map[cwd] else { continue }
            do {
                _ = try rewriteSessionFile(file, from: cwd, to: newCWD)
            } catch {
                results.append(AgentMigrationItemResult(
                    kind: .codex, description: file.lastPathComponent, error: "\(error)"))
            }
        }
        return results
    }

    private func sessionFiles() -> [URL] {
        guard let en = fm.enumerator(at: sessionsRoot,
                                     includingPropertiesForKeys: nil) else { return [] }
        return (en.compactMap { $0 as? URL })
            .filter { $0.pathExtension.lowercased() == "jsonl" }
    }

    static func pathMap(_ moves: [(old: URL, new: URL)]) -> [String: String] {
        var map: [String: String] = [:]
        for (old, new) in moves where old.path != new.path { map[old.path] = new.path }
        return map
    }

    /// 只读首行 session_meta 的 cwd（判归属足够；Codex 恒首行）。
    private func firstSessionCWD(of file: URL) -> String? {
        CodexSessionFile.firstSessionCWD(of: file)
    }

    /// 返回替换行数；0 = 无需改动（已迁过），不写回。
    private func rewriteSessionFile(_ file: URL, from oldCWD: String,
                                    to newCWD: String) throws -> Int {
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maxRewriteBytes else {
            throw CocoaError(.fileReadTooLarge, userInfo: [
                NSLocalizedDescriptionKey: "会话文件超过 \(maxRewriteBytes / 1024 / 1024)MB，跳过重写"])
        }
        let original = try String(contentsOf: file, encoding: .utf8)
        let hadTrailingNewline = original.hasSuffix("\n")
        var out = String()
        out.reserveCapacity(original.utf8.count)
        var replaced = 0
        for line in original.split(separator: "\n", omittingEmptySubsequences: false) {
            if let rewritten = Self.rewriteLine(String(line), from: oldCWD, to: newCWD) {
                out += rewritten
                replaced += 1
            } else {
                out += line
            }
            out += "\n"
        }
        if !hadTrailingNewline, out.hasSuffix("\n") { out.removeLast() }
        guard replaced > 0 else { return 0 }
        try out.write(to: file, atomically: true, encoding: .utf8)
        return replaced
    }

    /// 替换单行 `payload.cwd`；非匹配行返回 nil（保留原字节）。
    private static func rewriteLine(_ line: String, from oldCWD: String,
                                    to newCWD: String) -> String? {
        guard let obj = jsonObject(line) else { return nil }
        guard var payload = obj["payload"] as? [String: Any],
              payload["cwd"] as? String == oldCWD else { return nil }
        payload["cwd"] = newCWD
        var new = obj
        new["payload"] = payload
        guard let data = try? JSONSerialization.data(
            withJSONObject: new, options: [.sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }

    private static func jsonObject(_ line: String) -> [String: Any]? {
        CodexSessionFile.jsonObject(line)
    }
}

// MARK: - Codex 会话文件最小读取

/// 判定会话归属只需首行 session_meta 的 cwd（Codex 恒首行）。
/// 转载器与总览读取共用。
enum CodexSessionFile {
    static func firstSessionCWD(of file: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 64 * 1024)
        guard let nl = data.firstIndex(of: 0x0A) else { return nil }
        let line = String(decoding: data[data.startIndex..<nl], as: UTF8.self)
        guard let obj = jsonObject(line),
              obj["type"] as? String == "session_meta",
              let payload = obj["payload"] as? [String: Any] else { return nil }
        return payload["cwd"] as? String
    }

    static func jsonObject(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }
}

// MARK: - 门面

/// 聚合各 agent 转载器的门面，并负责计算受影响的路径对。
public struct AgentMemoryMigrationService: @unchecked Sendable {
    private let migrators: [any AgentMemoryMigrator]

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.migrators = [ClaudeMemoryMigrator(home: home), CodexMemoryMigrator(home: home)]
    }

    public func plan(_ moves: [(old: URL, new: URL)]) -> [AgentKind: AgentMigrationPlan] {
        var out: [AgentKind: AgentMigrationPlan] = [:]
        for migrator in migrators { out[migrator.kind] = migrator.plan(moves) }
        return out
    }

    public func migrate(_ moves: [(old: URL, new: URL)]) -> [AgentMigrationItemResult] {
        migrators.flatMap { $0.migrate(moves) }
    }

    /// 受影响路径对 = 空间根本身 + 每个直接子项（.gojo 除外），全用原始路径：
    /// 软链成员的解析目标（公共库真实路径）不变无需迁移，挂在软链路径下的
    /// 记忆由原始路径变体覆盖。子项列表取仍存在的那一侧（重命名后重试时旧侧已消失）。
    public static func affectedMoves(oldSpace: URL, newSpace: URL) -> [(old: URL, new: URL)] {
        let fm = FileManager.default
        let base = fm.fileExists(atPath: oldSpace.path) ? oldSpace : newSpace
        let children = ((try? fm.contentsOfDirectory(
            at: base, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [])
            .map { $0.lastPathComponent }
            .filter { $0 != ".gojo" }
        return [(oldSpace, newSpace)]
            + children.map { (oldSpace.appendingPathComponent($0),
                              newSpace.appendingPathComponent($0)) }
    }
}

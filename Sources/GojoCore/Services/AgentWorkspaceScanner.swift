import Foundation

/// 反向扫描本机 Claude Code / Codex 历史会话，发现所有曾使用过的项目路径。
///
/// 与 `AgentMemoryReader`（正向：给一个项目路径查它的记忆与会话）互补——
/// 这里遍历用户级会话目录，从会话文件里的 `cwd` 字段**反推**出原始项目路径。
///
/// - Claude：`~/.claude/projects/<dir>/*.jsonl`，每条 user/assistant 行顶层带精确 `cwd`
/// - Codex：`~/.codex/sessions/**/*.jsonl`，首行 `session_meta.payload.cwd` 精确
///
/// 目录名（`claudeProjectDirName`）不可逆（`/`、`.`、空格都压成 `-`），故一律以 `cwd` 为准。
public struct AgentWorkspaceScanner: @unchecked Sendable {
    private let home: URL
    private let fm = FileManager.default

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    /// 扫描并返回所有发现的项目（按路径去重合并），最近使用者优先。
    public func scan() -> [DiscoveredAgentProject] {
        var byPath: [String: DiscoveredAgentProject] = [:]
        for proj in scanClaude() {
            byPath[proj.path.path] = proj
        }
        for proj in scanCodex() {
            if var existing = byPath[proj.path.path] {
                existing.kinds.formUnion(proj.kinds)
                existing.sessionCount += proj.sessionCount
                if let t = proj.lastUsed, t > (existing.lastUsed ?? .distantPast) {
                    existing.lastUsed = t
                }
                byPath[proj.path.path] = existing
            } else {
                byPath[proj.path.path] = proj
            }
        }
        // 统一回填 exists（磁盘上是否仍存在）
        let merged = byPath.mapValues { proj -> DiscoveredAgentProject in
            var p = proj
            p.exists = fm.fileExists(atPath: proj.path.path)
            return p
        }
        return merged.values.sorted {
            ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast)
        }
    }

    // MARK: Claude

    /// 遍历 `~/.claude/projects/*`：每个目录数 jsonl 文件、取最新 mtime，
    /// 并从任一 jsonl 读首条 `cwd != null` 行反推真实路径。
    private func scanClaude() -> [DiscoveredAgentProject] {
        let root = home.appendingPathComponent(".claude/projects", isDirectory: true)
        let dirs = (try? fm.contentsOfDirectory(at: root,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        var result: [DiscoveredAgentProject] = []
        for dir in dirs where isDirectory(dir) {
            guard let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            let jsonls = files.filter { $0.pathExtension.lowercased() == "jsonl" }
            guard !jsonls.isEmpty else { continue }

            // 反推 cwd：从 jsonl 中读首条非空 cwd
            var cwd: String?
            for f in jsonls {
                if let c = firstClaudeCwd(of: f) { cwd = c; break }
            }
            guard let cwd else { continue }

            var latest: Date?
            for f in jsonls {
                let m = (try? f.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? .distantPast
                if m > (latest ?? .distantPast) { latest = m }
            }
            result.append(DiscoveredAgentProject(
                path: URL(fileURLWithPath: cwd),
                kinds: [.claude],
                sessionCount: jsonls.count,
                lastUsed: latest,
                exists: false))   // exists 由 scan() 统一回填
        }
        return result
    }

    /// 读 Claude jsonl，返回首条非空的顶层 `cwd`。
    private func firstClaudeCwd(of url: URL) -> String? {
        var found: String?
        scanLines(of: url) { line in
            guard let obj = jsonObject(line) else { return true }
            if let cwd = obj["cwd"] as? String, !cwd.isEmpty {
                found = cwd
                return false
            }
            return true
        }
        return found
    }

    // MARK: Codex

    /// 遍历 `~/.codex/sessions/**/*.jsonl`，按 `session_meta.cwd` 聚合。
    private func scanCodex() -> [DiscoveredAgentProject] {
        let root = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        guard let en = fm.enumerator(at: root,
            includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        var agg: [String: (count: Int, latest: Date?)] = [:]
        for case let f as URL in en where f.pathExtension.lowercased() == "jsonl" {
            guard let cwd = codexCwd(of: f) else { continue }
            let m = (try? f.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            var entry = agg[cwd] ?? (0, nil)
            entry.count += 1
            if m > (entry.latest ?? .distantPast) { entry.latest = m }
            agg[cwd] = entry
        }
        return agg.map { cwd, val in
            DiscoveredAgentProject(
                path: URL(fileURLWithPath: cwd),
                kinds: [.codex],
                sessionCount: val.count,
                lastUsed: val.latest,
                exists: false)
        }
    }

    /// 读 Codex jsonl 首行 `session_meta.payload.cwd`（首行即停）。
    private func codexCwd(of url: URL) -> String? {
        var cwd: String?
        scanLines(of: url) { line in
            if let obj = jsonObject(line),
               (obj["type"] as? String) == "session_meta",
               let payload = obj["payload"] as? [String: Any],
               let c = payload["cwd"] as? String, !c.isEmpty {
                cwd = c
            }
            return false   // 仅首行
        }
        return cwd
    }

    // MARK: 文本/文件辅助

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func jsonObject(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    /// 流式按行读取，body 返回 false 时提前结束；bounded 避免读满超大文件。
    private func scanLines(of url: URL, maxBytes: Int = 512_000,
                           _ body: (String) -> Bool) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        var buffer = Data()
        var total = 0
        while total < maxBytes {
            let chunk = handle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty { break }
            total += chunk.count
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                buffer.removeSubrange(buffer.startIndex...nl)
                if !body(String(decoding: lineData, as: UTF8.self)) { return }
            }
        }
        if !buffer.isEmpty { _ = body(String(decoding: buffer, as: UTF8.self)) }
    }
}

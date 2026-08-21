import Foundation

/// 从用户级目录读取 Claude / Codex 对某项目的记忆与历史会话。
/// - Claude：~/.claude/projects/<编码路径>/，含 memory/*.md 与会话 *.jsonl
/// - Codex：~/.codex/sessions/**/*.jsonl，按首行 session_meta.cwd 过滤本项目
public struct AgentMemoryReader: @unchecked Sendable {
    private let home: URL
    private let fm = FileManager.default

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    public func snapshot(for kind: AgentKind, projectPath: URL) -> AgentMemorySnapshot {
        switch kind {
        case .claude: return claudeSnapshot(projectPath: projectPath)
        case .codex:  return codexSnapshot(projectPath: projectPath)
        }
    }

    // MARK: Claude

    /// Claude Code 把 cwd 里的每个非字母数字字符替换成 `-` 作为目录名。
    /// 例：/Users/x/.cc-switch/skills → -Users-x--cc-switch-skills
    public static func claudeProjectDirName(for path: String) -> String {
        String(path.map { $0.isLetter || $0.isNumber ? $0 : "-" })
    }

    private func claudeSnapshot(projectPath: URL) -> AgentMemorySnapshot {
        let root = home.appendingPathComponent(".claude/projects", isDirectory: true)
        // 成员可能是指向公共空间的软链接，用户实际在真实路径下跑 claude；
        // 原始路径与解析后路径都试，取存在的那个目录。
        let candidates = [projectPath.path, projectPath.resolvingSymlinksInPath().path]
        let dir = candidates
            .map { root.appendingPathComponent(Self.claudeProjectDirName(for: $0), isDirectory: true) }
            .first { fm.fileExists(atPath: $0.path) }
            ?? root.appendingPathComponent(
                Self.claudeProjectDirName(for: projectPath.path), isDirectory: true)
        let available = fm.fileExists(atPath: dir.path)

        var docs: [MemoryDoc] = []
        let memoryDir = dir.appendingPathComponent("memory", isDirectory: true)
        if let items = try? fm.contentsOfDirectory(at: memoryDir,
                                                   includingPropertiesForKeys: nil) {
            for f in items where f.pathExtension.lowercased() == "md" {
                guard let content = try? String(contentsOf: f, encoding: .utf8) else { continue }
                docs.append(MemoryDoc(id: f.lastPathComponent, name: f.lastPathComponent,
                                      content: content))
            }
            // MEMORY.md 置顶，其余按名。
            docs.sort { a, b in
                if a.name == "MEMORY.md" { return true }
                if b.name == "MEMORY.md" { return false }
                return a.name < b.name
            }
        }

        var sessions: [AgentSession] = []
        if let items = try? fm.contentsOfDirectory(at: dir,
                    includingPropertiesForKeys: [.contentModificationDateKey]) {
            for f in items where f.pathExtension.lowercased() == "jsonl" {
                let id = f.deletingPathExtension().lastPathComponent
                let mtime = (try? f.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? .distantPast
                let title = claudeTitle(of: f) ?? id
                sessions.append(AgentSession(id: id, title: title, modifiedAt: mtime,
                                             filePath: f.path))
            }
        }
        sessions.sort { $0.modifiedAt > $1.modifiedAt }
        return AgentMemorySnapshot(kind: .claude, projectPath: projectPath.path,
                                   memoryDocs: docs, sessions: sessions, available: available)
    }

    /// 优先取 ai-title，其次首条非命令的用户消息。
    private func claudeTitle(of url: URL) -> String? {
        var aiTitle: String?
        var firstUser: String?
        scanLines(of: url) { line in
            guard let obj = jsonObject(line) else { return true }
            if let t = obj["type"] as? String {
                if t == "ai-title", let s = obj["aiTitle"] as? String, !s.isEmpty {
                    aiTitle = s
                    return false // 找到即停
                }
                if t == "user", (obj["isMeta"] as? Bool) != true, firstUser == nil,
                   let text = claudeUserText(obj["message"]) {
                    firstUser = text
                }
            }
            return true
        }
        return (aiTitle ?? firstUser).map(oneLine)
    }

    private func claudeUserText(_ message: Any?) -> String? {
        guard let m = message as? [String: Any] else { return nil }
        if let s = m["content"] as? String { return cleanCandidate(s) }
        if let parts = m["content"] as? [[String: Any]] {
            for p in parts where (p["type"] as? String) == "text" {
                if let s = p["text"] as? String, let c = cleanCandidate(s) { return c }
            }
        }
        return nil
    }

    // MARK: Codex

    private func codexSnapshot(projectPath: URL) -> AgentMemorySnapshot {
        let root = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        let available = fm.fileExists(atPath: root.path)
        // 成员可能是软链接，两个路径都接受。
        let targets: Set<String> = [projectPath.path,
                                    projectPath.resolvingSymlinksInPath().path]

        var sessions: [AgentSession] = []
        guard let en = fm.enumerator(at: root,
                    includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return AgentMemorySnapshot(kind: .codex, projectPath: projectPath.path,
                                       memoryDocs: [], sessions: [], available: available)
        }
        for case let f as URL in en where f.pathExtension.lowercased() == "jsonl" {
            guard let (id, title) = codexMeta(of: f, matching: targets) else { continue }
            let mtime = (try? f.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            sessions.append(AgentSession(id: id, title: title, modifiedAt: mtime,
                                         filePath: f.path))
        }
        sessions.sort { $0.modifiedAt > $1.modifiedAt }
        return AgentMemorySnapshot(kind: .codex, projectPath: projectPath.path,
                                   memoryDocs: [], sessions: sessions, available: available)
    }

    /// 读首行 session_meta 拿 cwd/id；cwd 不匹配立即放弃，匹配则继续找首条真实用户消息。
    private func codexMeta(of url: URL, matching targets: Set<String>) -> (id: String, title: String)? {
        var id: String?
        var matched = false
        var title: String?
        scanLines(of: url) { line in
            guard let obj = jsonObject(line) else { return true }
            let payload = obj["payload"] as? [String: Any]
            if (obj["type"] as? String) == "session_meta", let p = payload {
                guard let cwd = p["cwd"] as? String, targets.contains(cwd) else { return false }
                matched = true
                id = p["id"] as? String
                return true
            }
            guard matched else { return true }
            if let p = payload, (p["type"] as? String) == "message",
               (p["role"] as? String) == "user",
               let parts = p["content"] as? [[String: Any]] {
                for part in parts {
                    if let s = part["text"] as? String, let c = cleanCandidate(s) {
                        title = c
                        return false
                    }
                }
            }
            return true
        }
        guard matched, let id else { return nil }
        return (id, (title.map(oneLine)) ?? id)
    }

    // MARK: 空间总览

    /// 空间根本身 + 每个直接子项的两 agent 记忆计数（entries[0] 恒为空间根）。
    /// 只列目录计数、不读全文；Codex 一次枚举建 cwd → 会话数表，
    /// 再按各路径变体（原始 / 软链解析）匹配。
    public func spaceMemorySummary(in codingSpace: URL) -> SpaceMemorySummary {
        let codexRoot = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        let codexAvailable = fm.fileExists(atPath: codexRoot.path)
        var codexByCWD: [String: Int] = [:]
        if codexAvailable,
           let en = fm.enumerator(at: codexRoot, includingPropertiesForKeys: nil) {
            for case let f as URL in en where f.pathExtension.lowercased() == "jsonl" {
                if let cwd = CodexSessionFile.firstSessionCWD(of: f) {
                    codexByCWD[cwd, default: 0] += 1
                }
            }
        }

        func entry(_ url: URL, folderName: String?) -> MemberMemorySummary {
            // 软链成员两个路径变体都可能挂过会话（用户从软链或真实路径进入）。
            let variants: Set<String> = [url.path, url.resolvingSymlinksInPath().path]
            let sessions = variants.reduce(0) { $0 + (codexByCWD[$1] ?? 0) }
            return MemberMemorySummary(
                folderName: folderName,
                path: url.path,
                claude: claudeCount(for: url),
                codex: AgentMemoryCount(available: codexAvailable, sessions: sessions))
        }

        /// Claude：原始或解析路径的编码目录任一存在即 available。
        func claudeCount(for url: URL) -> AgentMemoryCount {
            guard let dir = claudeProjectDir(for: url) else { return .unavailable }
            let mdFiles = (try? fm.contentsOfDirectory(
                at: dir.appendingPathComponent("memory", isDirectory: true),
                includingPropertiesForKeys: nil)) ?? []
            let topFiles = (try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)) ?? []
            return AgentMemoryCount(
                available: true,
                memoryDocs: mdFiles.filter { $0.pathExtension.lowercased() == "md" }.count,
                sessions: topFiles.filter { $0.pathExtension.lowercased() == "jsonl" }.count)
        }

        var entries = [entry(codingSpace, folderName: nil)]
        let children = (try? fm.contentsOfDirectory(
            at: codingSpace, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])) ?? []
        for child in children where child.lastPathComponent != ".gojo" {
            entries.append(entry(child, folderName: child.lastPathComponent))
        }
        return SpaceMemorySummary(entries: entries)
    }

    /// Claude 项目记忆目录定位（原始路径优先，软链解析路径兜底），不存在返回 nil。
    private func claudeProjectDir(for url: URL) -> URL? {
        let root = home.appendingPathComponent(".claude/projects", isDirectory: true)
        let candidates = [url.path, url.resolvingSymlinksInPath().path]
        return candidates
            .map { root.appendingPathComponent(Self.claudeProjectDirName(for: $0), isDirectory: true) }
            .first { fm.fileExists(atPath: $0.path) }
    }

    // MARK: 文本工具

    /// 过滤注入内容（<...> 标签、AGENTS.md 前言）与空白，返回可读候选。
    private func cleanCandidate(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.hasPrefix("<"), !s.hasPrefix("# AGENTS.md"),
              !s.hasPrefix("caveat", caseSensitive: false) else { return nil }
        return s
    }

    private func oneLine(_ s: String) -> String {
        let flat = s.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flat.count > 80 ? String(flat.prefix(80)) + "…" : flat
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

private extension String {
    func hasPrefix(_ prefix: String, caseSensitive: Bool) -> Bool {
        caseSensitive ? hasPrefix(prefix)
            : lowercased().hasPrefix(prefix.lowercased())
    }
}

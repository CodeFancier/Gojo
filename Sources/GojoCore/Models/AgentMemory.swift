import Foundation

/// 编码助手类型：从用户级目录读取项目记忆/会话。
public enum AgentKind: String, CaseIterable, Hashable, Sendable, Identifiable {
    case claude
    case codex
    public var id: String { rawValue }
}

/// 一篇记忆文档（目前仅 Claude 的 memory/*.md）。
public struct MemoryDoc: Identifiable, Hashable, Sendable {
    public let id: String       // 相对文件名
    public let name: String
    public let content: String
    public init(id: String, name: String, content: String) {
        self.id = id; self.name = name; self.content = content
    }
}

/// 一条历史会话（可 resume）。
public struct AgentSession: Identifiable, Hashable, Sendable {
    public let id: String       // 会话 id（UUID），供 resume
    public let title: String
    public let modifiedAt: Date
    public let filePath: String
    public init(id: String, title: String, modifiedAt: Date, filePath: String) {
        self.id = id; self.title = title; self.modifiedAt = modifiedAt; self.filePath = filePath
    }
}

/// 某助手对某项目的记忆快照。
public struct AgentMemorySnapshot: Sendable {
    public let kind: AgentKind
    public let projectPath: String
    public let memoryDocs: [MemoryDoc]
    public let sessions: [AgentSession]
    /// 用户级目录是否存在（区分「没装/没用过」与「用过但无内容」）。
    public let available: Bool
    public init(kind: AgentKind, projectPath: String, memoryDocs: [MemoryDoc],
                sessions: [AgentSession], available: Bool) {
        self.kind = kind; self.projectPath = projectPath
        self.memoryDocs = memoryDocs; self.sessions = sessions; self.available = available
    }
}

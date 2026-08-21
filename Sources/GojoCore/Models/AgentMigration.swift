import Foundation

/// 单个 agent 的记忆转载 dry-run 计数。
/// unaffected* = 挂在软链成员真实路径（如公共库）下、不受重命名影响
/// 无需转载的数量——agent 用 getcwd() 记 cwd，软链被解析成物理路径，
/// 这类记忆的主键不随空间改名变化。
public struct AgentMigrationPlan: Sendable, Equatable {
    public let memoryDocs: Int
    public let sessions: Int
    public let unaffectedDocs: Int
    public let unaffectedSessions: Int

    public init(memoryDocs: Int = 0, sessions: Int = 0,
                unaffectedDocs: Int = 0, unaffectedSessions: Int = 0) {
        self.memoryDocs = memoryDocs; self.sessions = sessions
        self.unaffectedDocs = unaffectedDocs
        self.unaffectedSessions = unaffectedSessions
    }

    public var isEmpty: Bool { memoryDocs == 0 && sessions == 0 }
    public var unaffectedTotal: Int { unaffectedDocs + unaffectedSessions }
    public static let empty = AgentMigrationPlan()
}

/// 重命名编码空间前的整体计划：改名走向 + 受影响记忆概览（供 UI 提示）。
public struct CodingSpaceRenamePlan: Sendable, Equatable {
    public let oldURL: URL
    public let newURL: URL
    public let sanitizedNewName: String
    public let claude: AgentMigrationPlan
    public let codex: AgentMigrationPlan

    public init(oldURL: URL, newURL: URL, sanitizedNewName: String,
                claude: AgentMigrationPlan, codex: AgentMigrationPlan) {
        self.oldURL = oldURL; self.newURL = newURL
        self.sanitizedNewName = sanitizedNewName
        self.claude = claude; self.codex = codex
    }

    public var hasAgentMemory: Bool { !claude.isEmpty || !codex.isEmpty }

    /// 挂在真实路径下、不受影响的总量（docs, sessions）。
    public var unaffectedSummary: (docs: Int, sessions: Int) {
        (claude.unaffectedDocs + codex.unaffectedDocs,
         claude.unaffectedSessions + codex.unaffectedSessions)
    }

    public var hasUnaffectedMemory: Bool {
        claude.unaffectedTotal + codex.unaffectedTotal > 0
    }
}

/// 一项记忆内容的转载结果；error 为 nil 即成功。
public struct AgentMigrationItemResult: Sendable, Equatable, Identifiable {
    public let kind: AgentKind
    public let description: String
    public let error: String?

    public var id: String { "\(kind.rawValue):\(description)" }
    public var failed: Bool { error != nil }

    public init(kind: AgentKind, description: String, error: String? = nil) {
        self.kind = kind; self.description = description; self.error = error
    }
}

/// 重命名执行结果；migrationFailures 非空时可对 old/new URL 幂等重试。
public struct CodingSpaceRenameOutcome: Sendable, Equatable {
    public let oldURL: URL
    public let newURL: URL
    public let migrationResults: [AgentMigrationItemResult]

    public init(oldURL: URL, newURL: URL,
                migrationResults: [AgentMigrationItemResult] = []) {
        self.oldURL = oldURL; self.newURL = newURL
        self.migrationResults = migrationResults
    }

    public var migrationFailures: [AgentMigrationItemResult] {
        migrationResults.filter(\.failed)
    }
}

/// 一个 agent 对一个路径的记忆/会话计数（总览用，不读全文）。
public struct AgentMemoryCount: Sendable, Equatable {
    public let available: Bool
    public let memoryDocs: Int
    public let sessions: Int

    public init(available: Bool, memoryDocs: Int = 0, sessions: Int = 0) {
        self.available = available
        self.memoryDocs = memoryDocs; self.sessions = sessions
    }

    public static let unavailable = AgentMemoryCount(available: false)
}

/// 空间记忆总览条目：空间根本身（folderName = nil）或某个成员。
public struct MemberMemorySummary: Sendable, Equatable, Identifiable {
    public var id: String { path }
    public let folderName: String?
    public let path: String
    public let claude: AgentMemoryCount
    public let codex: AgentMemoryCount

    public init(folderName: String?, path: String,
                claude: AgentMemoryCount, codex: AgentMemoryCount) {
        self.folderName = folderName; self.path = path
        self.claude = claude; self.codex = codex
    }

    /// 展示名：成员用文件夹名，空间根用「空间根」。
    public var displayName: String { folderName ?? "空间根" }
}

/// 编码空间 × 两 agent 的记忆关联总览：entries[0] 恒为空间根本身。
public struct SpaceMemorySummary: Sendable, Equatable {
    public let entries: [MemberMemorySummary]

    public init(entries: [MemberMemorySummary]) { self.entries = entries }

    public var root: MemberMemorySummary? { entries.first }
    public var members: ArraySlice<MemberMemorySummary> { entries.dropFirst() }
}

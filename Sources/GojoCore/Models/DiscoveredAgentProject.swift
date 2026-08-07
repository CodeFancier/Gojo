import Foundation

/// 反向扫描发现的某个 AI 编码助手曾使用过的项目。
/// 由 `AgentWorkspaceScanner` 从用户级会话目录反推 `cwd` 得到。
public struct DiscoveredAgentProject: Identifiable, Hashable, Sendable {
    /// 用真实路径作唯一标识（同一路径在 Claude / Codex 两源间去重合并）
    public let id: String
    /// 从会话文件 cwd 字段反推出的真实项目路径
    public let path: URL
    /// 哪些助手曾在此项目工作（Claude / Codex，可能两者都有）
    public var kinds: Set<AgentKind>
    /// 检出的会话总数
    public var sessionCount: Int
    /// 最近一次会话时间
    public var lastUsed: Date?
    /// 项目目录当前是否仍在磁盘上（区分「已删除」的项目，仅展示不可导入）
    public var exists: Bool

    public var name: String { path.lastPathComponent }

    public init(path: URL, kinds: Set<AgentKind>,
                sessionCount: Int, lastUsed: Date?, exists: Bool) {
        self.id = path.path
        self.path = path
        self.kinds = kinds
        self.sessionCount = sessionCount
        self.lastUsed = lastUsed
        self.exists = exists
    }
}

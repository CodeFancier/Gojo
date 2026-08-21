import Foundation
import GojoCore

/// 空间顶栏「重命名」弹出的会话：持新名、dry-run 转载计划与执行结果。
struct CodingSpaceRenameSession: Identifiable {
    let id = UUID()
    let space: URL
    let currentName: String
    var name: String = ""
    /// 确认时是否把旧路径下的 agent 记忆一并转载到新路径。
    var migrateMemory: Bool = true
    /// 后台 dry-run 的转载计划；nil = 计算中。
    var plan: CodingSpaceRenamePlan?
    /// 执行结果；migrationFailures 非空时留在 sheet 供重试。
    var outcome: CodingSpaceRenameOutcome?
    /// 重命名本身的失败信息（留在 sheet 内展示，不关窗）。
    var errorMessage: String?
    var migrating: Bool = false
    /// 记忆转载进度；nil = 尚在改名/扫描阶段（显示不定进度）。
    var migrationProgress: AgentMigrationProgress?
}

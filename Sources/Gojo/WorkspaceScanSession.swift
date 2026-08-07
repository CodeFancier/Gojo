import Foundation
import GojoCore

enum WorkspaceScanPhase: Equatable {
    case scanning      // 正在扫描本机会话目录
    case review        // 展示结果，等待用户勾选与命名
    case importing     // 正在批量软链接进新编码空间
    case finished      // 导入完成（含部分失败）
}

enum WorkspaceScanResultStatus: Equatable {
    case idle
    case linking
    case linked
    case failed(String)
}

struct WorkspaceScanResult: Identifiable {
    let project: DiscoveredAgentProject
    var isSelected: Bool
    var status: WorkspaceScanResultStatus
    var id: String { project.id }
}

struct WorkspaceScanSession: Identifiable {
    let id = UUID()
    var phase: WorkspaceScanPhase = .scanning
    var results: [WorkspaceScanResult] = []
    var spaceName: String = "已发现项目"

    var hasFailures: Bool {
        results.contains { if case .failed = $0.status { return true }; return false }
    }

    /// 可导入的勾选项（勾选且项目仍存在于磁盘）。
    var selectedForImport: [WorkspaceScanResult] {
        results.filter { $0.isSelected && $0.project.exists }
    }

    var discoveredCount: Int { results.count }
}

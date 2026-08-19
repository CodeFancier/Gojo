import Foundation
import GojoCore

enum WorkspaceScanPhase: Equatable {
    case scanning      // 正在扫描编码空间根目录
    case review        // 展示结果，等待用户勾选
    case importing     // 正在逐个原位登记为独立编码空间
    case finished      // 导入完成（含部分失败）
}

enum WorkspaceScanResultStatus: Equatable {
    case idle
    case registering
    case registered
    case failed(String)
}

struct WorkspaceScanResult: Identifiable {
    let project: ExistingProjectFolder
    var isSelected: Bool
    var status: WorkspaceScanResultStatus
    var id: String { project.id }
}

struct WorkspaceScanSession: Identifiable {
    let id = UUID()
    var phase: WorkspaceScanPhase = .scanning
    var results: [WorkspaceScanResult] = []

    var hasFailures: Bool {
        results.contains { if case .failed = $0.status { return true }; return false }
    }

    var selectedForImport: [WorkspaceScanResult] {
        results.filter { $0.isSelected }
    }

    var discoveredCount: Int { results.count }
}

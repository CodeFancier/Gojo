import SwiftUI
import GojoCore

struct WorkspaceScanSheet: View {
    @EnvironmentObject private var state: AppState

    private var session: WorkspaceScanSession? { state.workspaceScanSession }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session {
                Text(title(for: session))
                    .font(.title2.bold())
                Text(message(for: session))
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)

                if session.phase == .review {
                    reviewControls(for: session)
                }

                if session.results.isEmpty {
                    emptyState(for: session)
                } else {
                    List(session.results) { result in
                        WorkspaceScanResultRow(
                            result: result,
                            phase: session.phase,
                            onToggle: { state.toggleScanResult(result.id) }
                        )
                    }
                    .listStyle(.inset)
                }

                controls(for: session)
            }
        }
        .padding(20)
        .frame(width: 560)
        .frame(minHeight: 440)
        .interactiveDismissDisabled(session?.phase == .importing)
    }

    private func title(for session: WorkspaceScanSession) -> String {
        switch session.phase {
        case .scanning: "正在扫描工作空间"
        case .review: "发现 \(session.discoveredCount) 个项目"
        case .importing: "正在导入到「\(session.spaceName)」"
        case .finished: session.hasFailures ? "部分项目未导入" : "导入完成"
        }
    }

    private func message(for session: WorkspaceScanSession) -> String {
        switch session.phase {
        case .scanning:
            "正在读取 Claude Code 与 Codex 的本机会话记录，反推所有曾用过的项目路径。"
        case .review:
            "勾选要纳入的项目，它们会以软链接形式加入一个新的编码空间——原文件不会被移动。"
        case .importing:
            "正在逐项创建符号链接，请不要关闭窗口。"
        case .finished:
            session.hasFailures
                ? "部分项目未能创建链接，请查看列表中的失败项。"
                : "所选项目已加入新编码空间。"
        }
    }

    @ViewBuilder
    private func reviewControls(for session: WorkspaceScanSession) -> some View {
        let existCount = session.results.filter { $0.project.exists }.count
        let selectedCount = session.results.filter { $0.isSelected }.count
        let allSelected = existCount > 0 && selectedCount >= existCount
        HStack(spacing: 12) {
            Button(allSelected ? "取消全选" : "全选") {
                state.selectAllScanResults(!allSelected)
            }
            Spacer()
            Text("编码空间名称")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
            TextField("已发现项目", text: Binding(
                get: { session.spaceName },
                set: { state.setSpaceName($0) }))
                .frame(width: 220)
        }
    }

    @ViewBuilder
    private func emptyState(for session: WorkspaceScanSession) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                if session.phase == .scanning {
                    ProgressView().controlSize(.small)
                    Text("正在扫描…").font(.caption).foregroundStyle(Color.textTertiary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(Color.textTertiary)
                    Text("没有发现 Claude Code 或 Codex 的工作空间")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.vertical, 48)
            Spacer()
        }
    }

    @ViewBuilder
    private func controls(for session: WorkspaceScanSession) -> some View {
        switch session.phase {
        case .scanning:
            HStack {
                Spacer()
                ProgressView().controlSize(.small)
                Text("扫描中").foregroundStyle(Color.textTertiary)
            }
        case .review:
            HStack {
                Button("取消", action: state.dismissWorkspaceScan)
                Spacer()
                Button(session.selectedForImport.isEmpty
                       ? "导入" : "导入选中的 \(session.selectedForImport.count) 个") {
                    state.importScannedWorkspaces()
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.selectedForImport.isEmpty)
            }
        case .importing:
            HStack {
                Spacer()
                ProgressView().controlSize(.small)
                Text("正在创建链接").foregroundStyle(Color.textTertiary)
            }
        case .finished:
            HStack {
                Spacer()
                Button("完成", action: state.dismissWorkspaceScan)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

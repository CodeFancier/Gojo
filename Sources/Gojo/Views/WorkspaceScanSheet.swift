import SwiftUI
import GojoCore

struct WorkspaceScanSheet: View {
    @EnvironmentObject private var state: AppState
    @State private var query = ""

    private var session: WorkspaceScanSession? { state.workspaceScanSession }

    /// 列表按搜索词过滤（匹配文件夹名或路径，大小写不敏感）。
    private var filteredResults(in session: WorkspaceScanSession) -> [WorkspaceScanResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return session.results }
        return session.results.filter {
            $0.project.name.localizedStandardContains(needle)
                || $0.project.url.path.localizedStandardContains(needle)
        }
    }

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
                } else if filteredResults(in: session).isEmpty {
                    Text("没有匹配的文件夹")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    List(filteredResults(in: session)) { result in
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
        case .scanning: "正在搜索已存在项目"
        case .review:
            let matched = filteredResults(in: session).count
            return matched == session.discoveredCount
                ? "发现 \(session.discoveredCount) 个文件夹"
                : "匹配 \(matched) / \(session.discoveredCount) 个文件夹"
        case .importing: "正在登记 \(session.selectedForImport.count) 个编码空间"
        case .finished: session.hasFailures ? "部分项目未导入" : "导入完成"
        }
    }

    private func message(for session: WorkspaceScanSession) -> String {
        switch session.phase {
        case .scanning:
            "正在列出编码空间根目录下的文件夹。"
        case .review:
            "勾选要纳入的文件夹，每个都会原位登记为独立编码空间——只在其内写入 .gojo 清单，原文件不会被移动或复制。"
        case .importing:
            "正在逐个登记，请不要关闭窗口。"
        case .finished:
            session.hasFailures
                ? "部分文件夹未能登记，请查看列表中的失败项。"
                : "所选文件夹已登记为独立编码空间。"
        }
    }

    @ViewBuilder
    private func reviewControls(for session: WorkspaceScanSession) -> some View {
        let visible = filteredResults(in: session)
        let allVisibleSelected = !visible.isEmpty
            && visible.allSatisfy(\.isSelected)
        HStack(spacing: 12) {
            Button(allVisibleSelected ? "取消全选" : "全选") {
                state.selectAllScanResults(
                    !allVisibleSelected, visibleIDs: Set(visible.map(\.id)))
            }
            Spacer()
            TextField("搜索文件夹", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .frame(maxWidth: 220)
                .background(Color.chrome, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func emptyState(for session: WorkspaceScanSession) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                if session.phase == .scanning {
                    ProgressView().controlSize(.small)
                    Text("正在搜索…").font(.caption).foregroundStyle(Color.textTertiary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(Color.textTertiary)
                    Text("根目录下没有可登记的文件夹")
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
                Text("搜索中").foregroundStyle(Color.textTertiary)
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
                Text("正在登记").foregroundStyle(Color.textTertiary)
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

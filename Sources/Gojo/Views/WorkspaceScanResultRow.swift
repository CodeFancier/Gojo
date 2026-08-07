import SwiftUI
import GojoCore

struct WorkspaceScanResultRow: View {
    let result: WorkspaceScanResult
    let phase: WorkspaceScanPhase
    var onToggle: () -> Void = {}

    private var project: DiscoveredAgentProject { result.project }

    var body: some View {
        HStack(spacing: 12) {
            leadingControl
            info
            Spacer(minLength: 0)
            statusView
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if phase == .review, project.exists { onToggle() }
        }
        .opacity(project.exists ? 1 : 0.6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var leadingControl: some View {
        if phase == .review {
            Image(systemName: result.isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(result.isSelected ? Color.lightBlue : Color.textTertiary)
                .frame(width: 20)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.textSecondary)
                .frame(width: 20)
                .accessibilityHidden(true)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(project.name)
                    .font(.body)
                    .foregroundStyle(project.exists ? Color.primary : Color.textTertiary)
                ForEach(Array(project.kinds).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { kind in
                    kindBadge(kind)
                }
            }
            Text(project.path.path)
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            if !project.exists {
                Text("项目已不在磁盘上，无法导入")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func kindBadge(_ kind: AgentKind) -> some View {
        Text(kind.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.lightBlue.opacity(0.2), in: Capsule())
            .foregroundStyle(Color.lightBlue)
    }

    @ViewBuilder private var statusView: some View {
        switch result.status {
        case .idle:
            Text("\(project.sessionCount) 个会话")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        case .linking:
            ProgressView().controlSize(.small)
                .accessibilityLabel("正在创建链接")
        case .linked:
            Label("已加入", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let msg):
            Label("失败", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .help(msg)
        }
    }
}

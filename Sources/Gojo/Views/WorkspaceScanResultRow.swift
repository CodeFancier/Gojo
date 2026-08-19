import SwiftUI
import GojoCore

struct WorkspaceScanResultRow: View {
    let result: WorkspaceScanResult
    let phase: WorkspaceScanPhase
    var onToggle: () -> Void = {}

    private var project: ExistingProjectFolder { result.project }

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
            if phase == .review { onToggle() }
        }
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
                    .foregroundStyle(Color.primary)
                if project.isGitRepository {
                    gitBadge
                }
            }
            Text(project.url.path)
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var gitBadge: some View {
        Text("Git")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.lightBlue.opacity(0.2), in: Capsule())
            .foregroundStyle(Color.lightBlue)
    }

    @ViewBuilder private var statusView: some View {
        switch result.status {
        case .idle:
            Text("待登记")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        case .registering:
            ProgressView().controlSize(.small)
                .accessibilityLabel("正在登记")
        case .registered:
            Label("已登记", systemImage: "checkmark.circle.fill")
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

import SwiftUI
import GojoCore

/// 公共空间统一列表行：目录与公共仓库同一形态，都可展开扫描直接子级 Git 仓库。
/// 已登记条目保留 Clone / 已克隆 / 长按删除；未登记 Git 仓库可「转为公共仓库」。
struct PublicSpaceEntryRow: View {
    let entry: PublicSpaceEntry
    /// 按 entry.publicProjectID 从 publicProjects 关联的登记项快照。
    let project: PublicProject?
    let isBusy: Bool
    let onClone: (UUID) -> Void
    let onDelete: (UUID) -> Void
    /// 传 relativePath（顶层条目自身或其子级仓库）。
    let onPromote: (String) -> Void

    @State private var isExpanded = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.bold())
                            .frame(width: 12)
                        leadingIcon
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            if !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(Color.textMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityTitle)
                .accessibilityHint(isExpanded ? "收起子项目" : "展开子项目")

                Spacer()
                trailingStatus
            }

            if isExpanded {
                expandedContent
                    .padding(.top, 10)
                    .padding(.leading, 34)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.surface)
        )
        .holdToDelete(enabled: project != nil && !isBusy) {
            confirmDelete = true
        }
        .confirmationDialog(
            "删除“\(entry.name)”公共项目？",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(project?.cloned == true ? "移到废纸篓" : "删除项目定义", role: .destructive) {
                if let id = project?.id { onDelete(id) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    // MARK: - 组成块

    @ViewBuilder
    private var leadingIcon: some View {
        if project != nil {
            SourceBadgeIcon(kind: .unjoinedPublic, size: 20,
                            badgeBackground: Color.chrome)
        } else if entry.isGitRepository {
            // 与同屏 NestedPublicProjectRow 对未登记仓库的既有处理一致
            Image(systemName: "shippingbox")
                .font(.system(size: 15))
                .foregroundStyle(Color.publicTeal)
                .frame(width: 20)
        } else {
            Image(systemName: "folder.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 20)
        }
    }

    private var subtitle: String {
        project?.url ?? entry.remoteURL
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if isBusy {
            ProgressView()
                .controlSize(.small)
        } else if let project {
            if project.cloned {
                Label("已克隆", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                    .labelStyle(.iconOnly)
            } else {
                Button("Clone") { onClone(project.id) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        } else if entry.isGitRepository {
            Button("转为公共仓库") { onPromote(entry.relativePath) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        } else if !entry.projects.isEmpty {
            Text("\(entry.projects.count) 个子仓库")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if !entry.isOnDisk {
            emptyMessage("克隆后可扫描子项目", systemImage: "arrow.down.circle")
        } else if entry.projects.isEmpty {
            emptyMessage("暂无子项目", systemImage: "tray")
        } else {
            VStack(spacing: 8) {
                ForEach(entry.projects) { child in
                    NestedPublicProjectRow(project: child, onPromote: onPromote)
                }
            }
        }
    }

    private func emptyMessage(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.chrome, in: RoundedRectangle(cornerRadius: 8))
    }

    private var accessibilityTitle: String {
        if project != nil { return "\(entry.name)，公共仓库" }
        if entry.isGitRepository { return "\(entry.name)，Git 仓库" }
        return "\(entry.name)，文件夹，\(entry.projects.count) 个子项目"
    }

    private var deleteConfirmationMessage: String {
        if project?.cloned == true {
            return "公共空间中的本地仓库将移到废纸篓。仍被编码空间引用的项目不能删除。"
        }
        return "将从公共空间移除该项目定义。"
    }
}

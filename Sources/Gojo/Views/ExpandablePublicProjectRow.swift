import SwiftUI
import GojoCore

struct ExpandablePublicProjectRow: View {
    let project: PublicProject
    let childProjects: [NestedPublicProject]
    let isBusy: Bool
    let onClone: () -> Void
    let onDelete: () -> Void
    let onPromote: (NestedPublicProject) -> Void

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
                        SourceBadgeIcon(kind: .unjoinedPublic, size: 20,
                                        badgeBackground: Color.chrome)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(project.url)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(Color.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(project.name)，公共项目")
                .accessibilityHint(isExpanded ? "收起子项目" : "展开子项目")

                Spacer()
                projectStatus
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
        .holdToDelete(enabled: !isBusy) {
            confirmDelete = true
        }
        .confirmationDialog(
            "删除“\(project.name)”公共项目？",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(project.cloned ? "移到废纸篓" : "删除项目定义", role: .destructive,
                   action: onDelete)
            Button("取消", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    @ViewBuilder
    private var projectStatus: some View {
        if isBusy {
            ProgressView()
                .controlSize(.small)
        } else if project.cloned {
            Label("已克隆", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
                .labelStyle(.iconOnly)
        } else {
            Button("Clone", action: onClone)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if !project.cloned {
            emptyMessage("克隆后可扫描子项目", systemImage: "arrow.down.circle")
        } else if childProjects.isEmpty {
            emptyMessage("暂无子项目", systemImage: "tray")
        } else {
            VStack(spacing: 8) {
                ForEach(childProjects) { child in
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

    private var deleteConfirmationMessage: String {
        if project.cloned {
            "公共空间中的本地仓库将移到废纸篓。仍被编码空间引用的项目不能删除。"
        } else {
            "将从公共空间移除该项目定义。"
        }
    }
}

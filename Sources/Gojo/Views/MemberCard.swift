import SwiftUI
import GojoCore

/// 编码空间里的成员卡：图标 + 名 + 分支；拖动到垃圾桶显示统一删除操作。
/// 进行中时角标位置换成进度指示器，操作禁用。
struct MemberCard: View {
    @EnvironmentObject var state: AppState
    let space: URL
    let member: ScannedMember

    @State private var hovering = false
    @State private var showBranchPicker = false
    @State private var branchOptions: [String] = []
    @State private var confirmSymlink = false
    @State private var confirmDelete = false

    private var busy: Bool { state.isBusy(space: space, folder: member.folderName) }

    private var isGit: Bool {
        switch member.form {
        case .standalone, .publicGit: return true
        // 软链接成员（公共项目软链接 / 外部项目软链接）不提供 Git 同步与切分支。
        case .publicSymlink, .externalSymlink: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                icon
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.folderName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(member.folderName)
                    if let b = member.branch {
                        Text(b).font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Color.textTertiary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                // 常驻的助手记忆入口：一眼可见、直接点。
                AgentMemoryButtons(projectURL: space.appendingPathComponent(member.folderName),
                                   displayName: member.folderName, compact: true)
            }
            .padding(12)

            if hovering && !busy {
                actionBar
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.surface))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.cardStroke, lineWidth: 1))
        .opacity(busy ? 0.7 : 1)
        .onHover { h in withAnimation(Motion.dropZone) { hovering = h } }
        .holdToDelete(enabled: !busy) {
            confirmDelete = true
        }
        .contextMenu { menuItems }
        .confirmationDialog("选择分支", isPresented: $showBranchPicker,
                            titleVisibility: .visible) {
            ForEach(branchOptions, id: \.self) { b in
                Button(b) { state.setBranch(space, folderName: member.folderName, branch: b) }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("切回软链接会丢失本地改动", isPresented: $confirmSymlink) {
            Button("仍然切换", role: .destructive) {
                state.switchToSymlink(space, folderName: member.folderName)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该成员的本地 clone 有未提交或未推送的改动，切回软链接将删除它们。")
        }
        .confirmationDialog("清理“\(member.folderName)”项目？",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("清理当前文件夹", role: .destructive) {
                state.removeMember(member.folderName, from: space)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    // MARK: 图标（含进行中态）

    @ViewBuilder private var icon: some View {
        if busy {
            ZStack {
                Image(systemName: "shippingbox")
                    .font(.system(size: 22)).foregroundStyle(Color.textSecondary)
                ProgressView().controlSize(.small)
                    .offset(x: 9, y: 8)
            }
            .frame(width: 22, height: 22)
        } else {
            SourceBadgeIcon(kind: SourceIconKind(member.form), size: 22,
                            badgeBackground: Color.chrome)
        }
    }

    // MARK: 操作条 + 菜单（共用 actions）

    private var actionBar: some View {
        HStack(spacing: 4) {
            if isGit {
                barButton("arrow.triangle.2.circlepath", "同步") {
                    state.syncMember(space, folderName: member.folderName)
                }
                barButton("arrow.triangle.branch", "切分支") {
                    branchOptions = state.branches(space, folderName: member.folderName)
                    showBranchPicker = true
                }
            }
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis").frame(width: 26, height: 22)
            }
            .menuStyle(.borderlessButton).fixedSize()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.bottom, 8)
    }

    private func barButton(_ symbol: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 26, height: 22)
        }
        .buttonStyle(.borderless).help(help)
    }

    @ViewBuilder private var menuItems: some View {
        switch member.form {
        case .publicSymlink:
            Button("转 Git 模式") { state.switchToGit(space, folderName: member.folderName) }
        case .publicGit:
            Button("转软链接模式") {
                if state.memberHasLocalChanges(space, folderName: member.folderName) {
                    confirmSymlink = true
                } else {
                    state.switchToSymlink(space, folderName: member.folderName)
                }
            }
        case .standalone:
            Button("同步") { state.syncMember(space, folderName: member.folderName) }
        case .externalSymlink:
            // 外部项目软链接：Gojo 不持有其公共项目记录，不提供模式切换或同步。
            EmptyView()
        }
    }

    private var deleteConfirmationMessage: String {
        if case .publicSymlink = member.form {
            return "只会清理当前编码空间中的软链接，不会删除公共仓库。"
        }
        if case .externalSymlink = member.form {
            return "只会删除当前编码空间中的软链接，不会移动外部项目本体。"
        }
        return "将永久清理当前项目文件夹，以及其中的全部子文件夹和文件。此操作无法撤销。"
    }
}

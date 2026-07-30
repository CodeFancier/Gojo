import SwiftUI
import GojoCore

/// 编码空间里的成员卡：图标 + 名 + 分支；悬停底部滑出操作条，右键同项。
/// 进行中时角标位置换成进度指示器，操作禁用。
struct MemberCard: View {
    @EnvironmentObject var state: AppState
    let space: URL
    let member: ScannedMember
    /// 拖拽开始时回传文件夹名，由领域展示「移动到其他空间」覆盖层。
    var onBeginDrag: (String) -> Void = { _ in }

    @State private var hovering = false
    @State private var showBranchPicker = false
    @State private var branchOptions: [String] = []
    @State private var confirmSymlink = false

    private var busy: Bool { state.isBusy(space: space, folder: member.folderName) }

    private var isGit: Bool {
        switch member.form {
        case .standalone, .publicGit: return true
        case .publicSymlink: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                icon
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.folderName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(1)
                    if let b = member.branch {
                        Text(b).font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Color(white: 0.55)).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)

            if hovering && !busy {
                actionBar
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: 168, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.055)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .opacity(busy ? 0.7 : 1)
        .onHover { h in withAnimation(Motion.dropZone) { hovering = h } }
        .contextMenu { menuItems }
        .onDrag {
            onBeginDrag(member.folderName)
            return NSItemProvider(object: DragPayload.member(space: space,
                                                             folder: member.folderName) as NSString)
        } preview: {
            HStack(spacing: 6) {
                SourceBadgeIcon(kind: SourceIconKind(member.form), size: 16)
                Text(member.folderName).lineLimit(1)
            }
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
        }
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
    }

    // MARK: 图标（含进行中态）

    @ViewBuilder private var icon: some View {
        if busy {
            ZStack {
                Image(systemName: "shippingbox")
                    .font(.system(size: 22)).foregroundStyle(Color(white: 0.82))
                ProgressView().controlSize(.small)
                    .offset(x: 9, y: 8)
            }
            .frame(width: 22, height: 22)
        } else {
            SourceBadgeIcon(kind: SourceIconKind(member.form), size: 22,
                            badgeBackground: Color(white: 0.14))
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
        }
    }
}

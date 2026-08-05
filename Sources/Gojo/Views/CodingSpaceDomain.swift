import SwiftUI
import GojoCore

/// 编码空间领域：顶栏（返回 + 名 + 终端/访达）和成员网格。
struct CodingSpaceDomain: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let space: URL

    @Binding var draggingProjectId: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 0) {
            DomainTopBar(title: space.lastPathComponent, memoryURL: space)

            ScrollView {
                let members = state.members(in: space)
                let pendingMembers = state.pendingMembers(in: space)
                if members.isEmpty && pendingMembers.isEmpty {
                    Text("空间里还没有仓库，从下方公共项目栏拖入项目，或在访达里放入现有仓库")
                        .font(.system(size: 12)).foregroundStyle(Color.textMuted)
                        .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(members) { member in
                            MemberCard(space: space, member: member)
                                .transition(.opacity)
                        }
                        ForEach(pendingMembers) { member in
                            PendingMemberCard(member: member)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .padding(16)
                    .animation(reduceMotion ? nil : Motion.dropZone, value: pendingMembers)
                }
            }
            .opacity(draggingProjectId == nil ? 1 : 0.35)

        }
        .background(DomainBackground())
    }
}

/// 领域顶栏：返回展示柜 + 标题 + 终端/访达。
struct DomainTopBar: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    /// 传入则在顶栏显示该目录（编码空间根）的 Claude/Codex 记忆入口。
    var memoryURL: URL? = nil

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : Motion.domain) { state.route = state.route.back() }
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless).keyboardShortcut("[", modifiers: .command)

            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            if let url = memoryURL {
                AgentMemoryButtons(projectURL: url, displayName: title, compact: false)
            }
            ToolbarButtons()
        }
        // 隐藏标题栏后红绿灯浮于左上，leading 让位避免压住返回按钮。
        .padding(.leading, 78).padding(.trailing, 14).padding(.vertical, 10)
        .background(Color.chrome)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }
}

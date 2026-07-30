import SwiftUI
import GojoCore

/// 编码空间领域：顶栏（返回 + 名 + 终端/访达）、成员网格、底部公共项目托盘。
struct CodingSpaceDomain: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let space: URL

    private let columns = [GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 12, alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            DomainTopBar(title: space.lastPathComponent)

            ScrollView {
                let members = state.members(in: space)
                if members.isEmpty {
                    Text("空间里还没有仓库，从下方托盘拖入公共项目，或在访达里放入现有仓库")
                        .font(.system(size: 12)).foregroundStyle(Color(white: 0.5))
                        .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(Array(members.enumerated()), id: \.element.folderName) { i, m in
                            MemberCard(space: space, member: m)
                                .transition(.opacity)
                        }
                    }
                    .padding(16)
                }
            }

            ProjectTray(space: space)
        }
        .background(DomainBackground())
    }
}

/// 领域顶栏：返回展示柜 + 标题 + 终端/访达。
struct DomainTopBar: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String

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
            ToolbarButtons()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }
}

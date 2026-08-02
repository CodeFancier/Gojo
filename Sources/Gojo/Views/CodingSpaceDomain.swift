import SwiftUI
import GojoCore

/// 编码空间领域：顶栏（返回 + 名 + 终端/访达）和成员网格。
struct CodingSpaceDomain: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let space: URL

    @Binding var draggingProjectId: UUID?
    @State private var movingFolder: String?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 12, alignment: .top)
    ]

    private var otherSpaces: [URL] { state.codingSpaces.filter { $0 != space } }

    var body: some View {
        VStack(spacing: 0) {
            DomainTopBar(title: space.lastPathComponent)

            ZStack(alignment: .top) {
                ScrollView {
                    let members = state.members(in: space)
                    if members.isEmpty {
                        Text("空间里还没有仓库，从下方公共项目栏拖入项目，或在访达里放入现有仓库")
                            .font(.system(size: 12)).foregroundStyle(Color.textMuted)
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                            ForEach(Array(members.enumerated()), id: \.element.folderName) { i, m in
                                MemberCard(space: space, member: m,
                                           onBeginDrag: { folder in
                                               guard !otherSpaces.isEmpty else { return }
                                               withAnimation(Motion.dropZone) { movingFolder = folder }
                                           })
                                    .transition(.opacity)
                            }
                        }
                        .padding(16)
                    }
                }
                .opacity(draggingProjectId == nil ? 1 : 0.35)

                if movingFolder != nil {
                    MoveTargets(source: space, targets: otherSpaces,
                                onMoved: { withAnimation(Motion.dropZone) { movingFolder = nil } },
                                onDismiss: { withAnimation(Motion.dropZone) { movingFolder = nil } })
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

        }
        .background(DomainBackground())
    }
}

/// 移动到其他编码空间的覆盖层：把成员拖到某个目标空间卡即移动。
/// 留在 CodingSpaceDomain 内、由本地 state 驱动——拖拽期间不切 route，
/// 否则源 MemberCard 的 NSView 被拆会取消拖拽（见 spec 5.4）。
private struct MoveTargets: View {
    @EnvironmentObject var state: AppState
    let source: URL
    let targets: [URL]
    let onMoved: () -> Void
    let onDismiss: () -> Void

    @State private var monitor: Any?
    @State private var hoverTarget: URL?

    var body: some View {
        VStack(spacing: 10) {
            Text("拖到其他编码空间移动").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(targets, id: \.self) { target in
                        card(target)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.chrome.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { e in
                DispatchQueue.main.async { onDismiss() }
                return e
            }
        }
        .onDisappear { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
    }

    private func card(_ target: URL) -> some View {
        let hot = hoverTarget == target
        return VStack(spacing: 6) {
            Image(systemName: "shippingbox.fill").font(.system(size: 20))
                .foregroundStyle(Color.lightBlue)
            Text(target.lastPathComponent).font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white).lineLimit(1)
        }
        .frame(width: 130, height: 84)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.coreBlue.opacity(hot ? 0.24 : 0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(Color.lightBlue.opacity(0.6)))
        .scaleEffect(hot ? 1.02 : 1)
        .animation(Motion.dropZone, value: hot)
        .onDrop(of: [.text], isTargeted: Binding(
            get: { hoverTarget == target },
            set: { h in hoverTarget = h ? target : (hoverTarget == target ? nil : hoverTarget) })) { providers in
            handleDrop(providers, to: target)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], to target: URL) -> Bool {
        guard let p = providers.first else { return false }
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            guard let s = obj as? String, let move = DragPayload.parseMember(s) else { return }
            DispatchQueue.main.async {
                hoverTarget = nil
                state.moveMember(move.folder, from: move.space, to: target)
                onMoved()
            }
        }
        return true
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

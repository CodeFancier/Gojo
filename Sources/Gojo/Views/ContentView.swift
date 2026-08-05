import SwiftUI
import GojoCore

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draggingPublicProjectId: UUID?

    var body: some View {
        ZStack {
            DomainBackground()
            routedLayout
        }
        .frame(minWidth: 720, minHeight: 460)
        .overlay(alignment: .top) {
            if let space = activeCodingSpace, let id = draggingPublicProjectId {
                DropZones(
                    draggingProjectId: id,
                    onDrop: { projectId, mode in
                        state.addPublicToSpace(space, projectId: projectId, mode: mode)
                        withAnimation(reduceMotion ? nil : Motion.dropZone) {
                            draggingPublicProjectId = nil
                        }
                    },
                    onDismiss: {
                        withAnimation(reduceMotion ? nil : Motion.dropZone) {
                            draggingPublicProjectId = nil
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 48)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        // 全程深色渐变 UI，强制深色外观：否则浅色系统模式下所有默认控件
        // （工具栏图标、菜单、返回箭头、省略号）会渲染成深色，压在深底上看不清。
        .preferredColorScheme(.dark)
        .tint(.lightBlue)
        .animation(reduceMotion ? nil : Motion.domain, value: state.route)
        .onChange(of: state.route) { route in
            switch route {
            case .codingSpace, .shelfDropping:
                break
            case .shelf, .publicSpace:
                draggingPublicProjectId = nil
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } })) {
            Button("好") { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "") }
        .sheet(item: $state.codingSpaceDeletionSession) { _ in
            CodingSpaceDeletionSheet()
        }
    }

    @ViewBuilder private var routedLayout: some View {
        if dynamicTypeSize.isAccessibilitySize, publicBarMode != nil {
            ScrollView(.vertical) {
                routeAndPublicBar(accessibilityLayout: true)
                    .frame(maxWidth: .infinity)
            }
        } else {
            routeAndPublicBar(accessibilityLayout: false)
        }
    }

    private func routeAndPublicBar(accessibilityLayout: Bool) -> some View {
        VStack(spacing: 0) {
            content
                .frame(minHeight: accessibilityLayout ? accessibilityRouteMinimumHeight : nil)

            if let mode = publicBarMode {
                PersistentPublicSpaceBar(
                    mode: mode,
                    onOpen: openPublicSpace,
                    onDragProject: beginPublicProjectDrag
                )
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch state.route {
        case .shelf:
            ShelfView().transition(shelfTransition)
        case .publicSpace:
            PublicSpaceDomain().transition(domainTransition)
        case .codingSpace(let u):
            CodingSpaceDomain(space: u, draggingProjectId: $draggingPublicProjectId)
                .transition(domainTransition)
        case .shelfDropping(let source, _):
            // 拖拽期不会切到此分支（投放覆盖层留在领域内），保留作防御性映射。
            CodingSpaceDomain(space: source, draggingProjectId: $draggingPublicProjectId)
                .transition(domainTransition)
        }
    }

    private var publicBarMode: PublicSpaceBarMode? {
        switch state.route {
        case .shelf:
            .summary
        case .codingSpace, .shelfDropping:
            .searchable
        case .publicSpace:
            nil
        }
    }

    private var activeCodingSpace: URL? {
        switch state.route {
        case .codingSpace(let space):
            space
        case .shelfDropping(let source, _):
            source
        case .shelf, .publicSpace:
            nil
        }
    }

    private var accessibilityRouteMinimumHeight: CGFloat {
        switch state.route {
        case .codingSpace, .shelfDropping:
            260
        case .shelf, .publicSpace:
            0
        }
    }

    private func openPublicSpace() {
        withAnimation(reduceMotion ? nil : Motion.domain) {
            state.route = .publicSpace
        }
    }

    private func beginPublicProjectDrag(_ id: UUID) {
        switch state.route {
        case .codingSpace, .shelfDropping:
            withAnimation(reduceMotion ? nil : Motion.dropZone) {
                draggingPublicProjectId = id
            }
        case .shelf, .publicSpace:
            break
        }
    }

    /// 领域展开：从略小处放大就位 + 淡入；reduceMotion 时纯淡入。
    private var domainTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity)
    }
    /// 返回展示柜：略微收缩淡出。
    private var shelfTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 1.04).combined(with: .opacity)
    }
}

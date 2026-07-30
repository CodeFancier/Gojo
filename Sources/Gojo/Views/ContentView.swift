import SwiftUI
import GojoCore

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            DomainBackground()
            content
        }
        .frame(minWidth: 720, minHeight: 460)
        .animation(reduceMotion ? nil : Motion.domain, value: state.route)
        .alert("操作失败", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } })) {
            Button("好") { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "") }
    }

    @ViewBuilder private var content: some View {
        switch state.route {
        case .shelf:
            ShelfView().transition(shelfTransition)
        case .publicSpace:
            PublicSpaceDomain().transition(domainTransition)
        case .codingSpace(let u):
            CodingSpaceDomain(space: u).transition(domainTransition)
        case .shelfDropping(let source, _):
            // 拖拽期不会切到此分支（投放覆盖层留在领域内），保留作防御性映射。
            CodingSpaceDomain(space: source).transition(domainTransition)
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

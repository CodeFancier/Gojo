import SwiftUI

struct HoldToDeleteModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    let enabled: Bool
    let trailingInset: CGFloat
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .allowsHitTesting(!isPresented)

            if isPresented {
                DeletionActionBar(
                    onDelete: confirmDelete,
                    onCancel: dismiss
                )
                .padding(.vertical, 8)
                .padding(.leading, 8)
                .padding(.trailing, trailingInset)
                .transition(actionTransition)
                .zIndex(1)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            if isPresented {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.red.opacity(0.85), lineWidth: 2)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .scaleEffect(isPresented && !reduceMotion ? 0.985 : 1)
        .onLongPressGesture(minimumDuration: 0.6) {
            present()
        }
        .accessibilityAction(named: "显示删除操作") {
            present()
        }
        .help(enabled ? "按住显示删除操作" : "")
        .onChange(of: enabled) { enabled in
            if !enabled {
                isPresented = false
            }
        }
    }

    private var actionTransition: AnyTransition {
        if reduceMotion {
            .opacity
        } else {
            .move(edge: .trailing)
                .combined(with: .scale(scale: 0.92, anchor: .trailing))
                .combined(with: .opacity)
        }
    }

    private func present() {
        guard enabled else { return }
        // 长按识别成功时鼠标通常仍按住：这里直接同步置位，不要用 withAnimation。
        // 包进动画 transaction 后，这次状态变更会在「静止按压、无新输入事件」期间被
        // 挂起，直到下一次输入（如鼠标移出卡片触发 onHover）才刷新——表现为
        // 「要把鼠标移出项目框、删除按钮才出现」。消失走 dismiss()，发生在松开后的
        // 正常事件循环里，仍保留动画。
        isPresented = true
    }

    private func confirmDelete() {
        dismiss()
        onDelete()
    }

    private func dismiss() {
        withAnimation(reduceMotion ? nil : Motion.dropZone) {
            isPresented = false
        }
    }
}

extension View {
    func holdToDelete(enabled: Bool = true, trailingInset: CGFloat = 8,
                      onDelete: @escaping () -> Void) -> some View {
        modifier(HoldToDeleteModifier(
            enabled: enabled,
            trailingInset: trailingInset,
            onDelete: onDelete
        ))
    }
}

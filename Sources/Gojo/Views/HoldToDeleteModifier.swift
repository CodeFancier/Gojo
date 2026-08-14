import SwiftUI

struct HoldToDeleteModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false
    /// 按压进行中：从按下就开始渐显红框，让等待时长可感知。
    @State private var isPressing = false

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
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.red.opacity(strokeOpacity), lineWidth: 2)
                .allowsHitTesting(false)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: isPressing)
        }
        .scaleEffect(pressScale)
        // 默认 maximumDistance 仅约 10pt，在滚动容器里按压时轻微漂移即被判失败、
        // 又被 ScrollView 的 pan 手势抢占；放宽到 80pt 并缩短时长，长按才够灵敏。
        .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 80) {
            present()
        } onPressingChanged: { pressing in
            isPressing = pressing
        }
        .accessibilityAction(named: "显示删除操作") {
            present()
        }
        .help(enabled ? "按住显示删除操作" : "")
        .onChange(of: enabled) { enabled in
            if !enabled {
                isPresented = false
                isPressing = false
            }
        }
    }

    /// 按压时半显、成功后全显的红框透明度。
    private var strokeOpacity: Double {
        if isPresented { return 0.85 }
        if enabled && isPressing { return 0.45 }
        return 0
    }

    private var pressScale: CGFloat {
        guard !reduceMotion else { return 1 }
        if isPresented { return 0.985 }
        if enabled && isPressing { return 0.995 }
        return 1
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

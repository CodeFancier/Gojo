import SwiftUI

/// 按住进入待删状态：卡片呈现选中效果，右缘滑出垃圾桶图标；
/// 把卡片拖到垃圾桶上松手即删除，拖到其他位置或原地松手则弹回取消。
///
/// 用 LongPressGesture.sequenced(before: DragGesture) 一条手势链实现
/// 「按住→拖动」：长按成功即被手势独占，不会在松手时误触发卡片按钮的
/// 导航动作；拖动事件持续产生输入，也不受静止按压期间渲染挂起的影响。
struct HoldToDeleteModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isArmed = false
    @State private var dragTranslation: CGSize = .zero
    @State private var dragLocation: CGPoint?
    @State private var trashFrame: CGRect = .zero

    let enabled: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isArmed)
            // 选中态红框：悬停垃圾桶时加浓提示即将删除
            .overlay {
                if isArmed {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(hoveringTrash ? 1 : 0.8), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(pressScale)
            .offset(isArmed ? dragTranslation : .zero)
            // 垃圾桶挂在 offset 之后：卡片拖走，垃圾桶留在原地等投放
            .overlay(alignment: .trailing) {
                if isArmed {
                    trashIcon
                        .padding(.trailing, 10)
                        .background(trashReporter)
                        .zIndex(2)
                }
            }
            .contentShape(Rectangle())
            .gesture(holdAndDrag)
            .accessibilityAction(named: "删除") {
                onDelete()
            }
            .help(enabled ? "按住卡片，拖到垃圾桶上松手删除" : "")
            .onChange(of: enabled) { enabled in
                if !enabled { reset() }
            }
    }

    // MARK: 手势

    private var holdAndDrag: some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 80)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .first(true):
                    guard enabled, !isArmed else { return }
                    // 同步置位、不包动画：静止按压期间的状态变更会被挂起到
                    // 下一次输入事件才刷新（见 present() 时期的历史教训）。
                    // 新交互里用户接下来必然拖动，拖动事件会立即补上渲染。
                    isArmed = true
                case .second(true, let drag?):
                    dragTranslation = drag.translation
                    dragLocation = drag.location
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag?):
                    if dropTarget.contains(drag.location) {
                        reset()
                        onDelete()
                    } else {
                        cancel()
                    }
                default:
                    cancel()
                }
            }
    }

    /// 垃圾桶命中区域：图标外扩一圈，降低投放精度要求。
    private var dropTarget: CGRect {
        trashFrame.insetBy(dx: -14, dy: -14)
    }

    private var hoveringTrash: Bool {
        guard isArmed, let loc = dragLocation else { return false }
        return dropTarget.contains(loc)
    }

    // MARK: 待删态视觉

    private var pressScale: CGFloat {
        guard !reduceMotion, isArmed else { return 1 }
        return hoveringTrash ? 0.92 : 0.97
    }

    private var trashIcon: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(hoveringTrash ? Color.white : Color.red)
            .frame(width: 32, height: 32)
            .background(Circle().fill(hoveringTrash ? Color.red : Color.chrome))
            .overlay(Circle().strokeBorder(Color.red.opacity(0.6), lineWidth: 1.5))
            .scaleEffect(hoveringTrash ? 1.18 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6),
                       value: hoveringTrash)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            .allowsHitTesting(false)
    }

    /// 垃圾桶位置固定，出现时读一次全局 frame 即可用于投放判定。
    private var trashReporter: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { trashFrame = geo.frame(in: .global) }
        }
    }

    // MARK: 状态

    private func cancel() {
        withAnimation(reduceMotion ? nil : Motion.dropZone) {
            reset()
        }
    }

    private func reset() {
        isArmed = false
        dragTranslation = .zero
        dragLocation = nil
    }
}

extension View {
    func holdToDelete(enabled: Bool = true,
                      onDelete: @escaping () -> Void) -> some View {
        modifier(HoldToDeleteModifier(enabled: enabled, onDelete: onDelete))
    }
}

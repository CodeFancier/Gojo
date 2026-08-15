import SwiftUI

/// 拖动进入待删状态：按下卡片并拖动后右缘滑出垃圾桶图标；
/// 把卡片拖到垃圾桶上松手即删除，拖到其他位置松手则弹回取消。
///
/// 用带触发阈值的 DragGesture + highPriorityGesture 实现「拖动→删除」：
/// 位移超过阈值手势才激活，普通点击仍走卡片按钮；手势一旦激活，
/// 松手不会误触发按钮的导航动作。此前 LongPressGesture.sequenced(before:)
/// 在 macOS 的 Button + ScrollView 组合下进不了识别（垃圾桶不出现、卡片
/// 拖不动），故弃用。
struct HoldToDeleteModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isArmed = false
    @State private var dragTranslation: CGSize = .zero
    /// 进入待删态那一刻的平移量：从该点起算增量，卡片不因越过阈值而跳一下。
    @State private var armOrigin: CGSize = .zero
    @State private var dragLocation: CGPoint?
    @State private var trashFrame: CGRect = .zero

    let enabled: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            // 选中态红框：悬停垃圾桶时加浓提示即将删除
            .overlay {
                if isArmed {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(hoveringTrash ? 1 : 0.8), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(pressScale)
            .offset(isArmed ? effectiveTranslation : .zero)
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
            .highPriorityGesture(dragToTrash)
            .accessibilityAction(named: "删除") {
                onDelete()
            }
            .help(enabled ? "拖动卡片到垃圾桶上松手删除" : "")
            .onChange(of: enabled) { enabled in
                if !enabled { reset() }
            }
    }

    // MARK: 手势

    private var dragToTrash: some Gesture {
        DragGesture(minimumDistance: HoldToDeleteModel.armThreshold,
                    coordinateSpace: .global)
            .onChanged { value in
                guard enabled else { return }
                if !isArmed {
                    armOrigin = value.translation
                    withAnimation(reduceMotion ? nil : Motion.dropZone) {
                        isArmed = true
                    }
                }
                dragTranslation = value.translation
                dragLocation = value.location
            }
            .onEnded { value in
                guard isArmed else { return }
                if model.hitsTrash(value.location) {
                    reset()
                    onDelete()
                } else {
                    cancel()
                }
            }
    }

    private var model: HoldToDeleteModel {
        HoldToDeleteModel(trashFrame: trashFrame)
    }

    private var effectiveTranslation: CGSize {
        CGSize(width: dragTranslation.width - armOrigin.width,
               height: dragTranslation.height - armOrigin.height)
    }

    private var hoveringTrash: Bool {
        isArmed && model.hitsTrash(dragLocation)
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
        armOrigin = .zero
        dragLocation = nil
    }
}

extension View {
    func holdToDelete(enabled: Bool = true,
                      onDelete: @escaping () -> Void) -> some View {
        modifier(HoldToDeleteModifier(enabled: enabled, onDelete: onDelete))
    }
}

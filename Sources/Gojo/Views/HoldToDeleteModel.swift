import CoreGraphics

/// 拖动删除交互的纯判定逻辑，与 SwiftUI 手势解耦以便单测
/// （可测性先例见 CarouselKeyEventMonitor）。
struct HoldToDeleteModel {
    /// 垃圾桶命中区域在图标 frame 基础上外扩一圈，降低投放精度要求。
    static let hitInset: CGFloat = 14
    /// 位移超过该值才进入待删态，避免与普通点击冲突。
    static let armThreshold: CGFloat = 12

    let trashFrame: CGRect

    var dropTarget: CGRect {
        trashFrame.insetBy(dx: -Self.hitInset, dy: -Self.hitInset)
    }

    /// 拖动位置是否命中垃圾桶投放区；无位置（未拖动）视为未命中。
    func hitsTrash(_ location: CGPoint?) -> Bool {
        guard let location else { return false }
        return dropTarget.contains(location)
    }
}

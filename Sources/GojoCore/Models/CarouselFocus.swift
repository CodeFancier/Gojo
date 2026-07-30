import CoreGraphics

/// 展示柜焦点计算：给定各卡中心 x 与视口中心 x，算出焦点索引。
public enum CarouselFocus {
    /// 返回离视口中心最近的卡索引；空数组返回 nil。
    public static func nearestIndex(cardCentersX: [CGFloat], viewportCenterX: CGFloat) -> Int? {
        guard !cardCentersX.isEmpty else { return nil }
        return cardCentersX.enumerated()
            .min { abs($0.element - viewportCenterX) < abs($1.element - viewportCenterX) }?
            .offset
    }

    /// 键盘步进用：把索引夹到 [0, count-1]；count<=0 返回 0。
    public static func clampedIndex(_ i: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(0, min(i, count - 1))
    }
}

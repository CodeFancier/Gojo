// CGFloat/CGSize 在 Apple 平台来自 CoreGraphics，Linux（corelibs-foundation）来自 Foundation。
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

public struct CarouselCardMetrics: Equatable, Sendable {
    public let focusedSize: CGSize
    public let sideSize: CGSize
    public let horizontalInset: CGFloat
    public let spacing: CGFloat

    public static func calculate(
        viewportWidth: CGFloat,
        availableHeight: CGFloat
    ) -> CarouselCardMetrics {
        let safeWidth = max(0, viewportWidth)
        let safeHeight = max(0, availableHeight)
        let focusedWidth = min(360, max(240, safeWidth * 0.36))
        let focusedHeight = min(250, max(180, safeHeight - 44))
        let sideWidth = max(150, focusedWidth * 0.64)
        let sideHeight = max(140, focusedHeight * 0.76)
        return CarouselCardMetrics(
            focusedSize: CGSize(width: focusedWidth, height: focusedHeight),
            sideSize: CGSize(width: sideWidth, height: sideHeight),
            horizontalInset: max(0, (safeWidth - focusedWidth) / 2),
            spacing: min(22, max(12, safeWidth * 0.018))
        )
    }
}

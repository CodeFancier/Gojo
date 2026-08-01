import SwiftUI

/// 首页：编码空间轮播。
struct ShelfView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let minimumAccessibleHeight: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            if dynamicTypeSize.isAccessibilitySize,
               geometry.size.height < minimumAccessibleHeight {
                ScrollView(.vertical) {
                    carousel
                        .frame(height: minimumAccessibleHeight)
                }
            } else {
                carousel
            }
        }
        .background(DomainBackground())
    }

    private var carousel: some View {
        CodingSpaceCarousel()
            .padding(.top, 48)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

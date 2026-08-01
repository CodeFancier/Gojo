import SwiftUI

/// 首页：编码空间轮播。
struct ShelfView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var carouselTitleLineHeight: CGFloat = 24

    private let wordmarkClearance: CGFloat = 48
    private let authorClearance: CGFloat = 28
    private let minimumFocusedCardHeight: CGFloat = 180
    private let paginationHeight: CGFloat = 26

    private var minimumAccessibleHeight: CGFloat {
        wordmarkClearance
            + carouselTitleLineHeight
            + minimumFocusedCardHeight
            + paginationHeight
            + authorClearance
    }

    var body: some View {
        carousel
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? minimumAccessibleHeight : nil)
            .background(DomainBackground())
            .overlay(alignment: .topLeading) {
                BrandWordmark(height: 26)
                    .padding(.leading, 84)
                    .padding(.top, 14)
            }
            .overlay(alignment: .bottomTrailing) {
                AuthorCredit()
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
            }
    }

    private var carousel: some View {
        CodingSpaceCarousel()
            .padding(.top, wordmarkClearance)
            .padding(.bottom, authorClearance)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

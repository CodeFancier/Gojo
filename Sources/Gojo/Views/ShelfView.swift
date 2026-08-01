import SwiftUI

/// 首页：编码空间轮播。
struct ShelfView: View {
    var body: some View {
        CodingSpaceCarousel()
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

}

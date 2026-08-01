import SwiftUI

/// 首页：公共空间摘要和编码空间轮播。
struct ShelfView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical) {
                    sections(spacing: 12, carouselHeight: 340)
                        .padding(.bottom, 36)
                }
            } else {
                sections(spacing: 18, carouselHeight: nil)
            }
        }
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

    private func sections(spacing: CGFloat, carouselHeight: CGFloat?) -> some View {
        VStack(spacing: spacing) {
            PublicSpaceSummary(
                isConfigured: state.publicSpaceFolder != nil,
                projects: state.publicProjects,
                onOpen: openPublicSpace
            )
            .padding(.horizontal, 42)
            .padding(.top, 58)

            CodingSpaceCarousel()
                .frame(height: carouselHeight)
        }
    }

    private func openPublicSpace() {
        withAnimation(reduceMotion ? nil : Motion.domain) {
            state.route = .publicSpace
        }
    }
}

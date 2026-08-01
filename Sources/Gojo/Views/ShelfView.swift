import SwiftUI

/// 首页：公共空间摘要和编码空间轮播。
struct ShelfView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            PublicSpaceSummary(
                isConfigured: state.publicSpaceFolder != nil,
                projects: state.publicProjects,
                onOpen: openPublicSpace
            )
            .padding(.horizontal, 42)
            .padding(.top, 58)

            CodingSpaceCarousel()
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

    private func openPublicSpace() {
        withAnimation(reduceMotion ? nil : Motion.domain) {
            state.route = .publicSpace
        }
    }
}

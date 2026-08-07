import SwiftUI

/// 首页：编码空间轮播。
struct ShelfView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var carouselTitleLineHeight: CGFloat = 24
    @ScaledMetric(relativeTo: .caption) private var authorLineHeight: CGFloat = 16

    private let wordmarkClearance: CGFloat = 48
    private let authorBottomPadding: CGFloat = 12
    private let minimumFocusedCardHeight: CGFloat = 180
    private let paginationHeight: CGFloat = 26

    private var authorClearance: CGFloat {
        authorLineHeight + authorBottomPadding
    }

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
                    .padding(.bottom, authorBottomPadding)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    state.startWorkspaceScan()
                } label: {
                    Label("扫描工作空间", systemImage: "rectangle.and.text.magnifyingglass")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .padding(8)
                        .background(Color.lightBlue.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .help("扫描本机 Claude Code / Codex 工作空间")
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
    }

    private var carousel: some View {
        CodingSpaceCarousel()
            .padding(.top, wordmarkClearance)
            .padding(.bottom, authorClearance)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

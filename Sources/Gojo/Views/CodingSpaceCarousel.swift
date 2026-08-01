import SwiftUI
import GojoCore

/// 各卡中心 x 的 PreferenceKey：卡片通过 GeometryReader 上报，容器据此算焦点。
private struct CardCenterKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 编码空间的焦点轮播。
struct CodingSpaceCarousel: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var focusIndex = 0
    /// 居中动画期间置真，禁止滚动位置驱动的 preferenceChange 抢焦点致放大闪烁。
    @State private var scrollLock = false
    /// 滚动代次：仅最新一次滚动负责解锁，避免快速连续 hover 的解锁竞态。
    @State private var scrollGen = 0

    private var items: [ShelfItem] {
        state.codingSpaces.map(ShelfItem.coding) + [.newSpace]
    }

    var body: some View {
        VStack(spacing: 0) {
            Label("编码空间", systemImage: "shippingbox.fill")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 42)

            GeometryReader { geo in
                let viewportCenterX = geo.size.width / 2
                // 200pt 焦点卡 + 20pt 底部留白 + 32pt 圆点区；最小窗口也不会挤到圆点。
                let topPadding = min(52, max(24, geo.size.height - 252))
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                                card(idx, item, proxy: proxy)
                                    .id(idx)
                                    .background(reporter(idx))
                            }
                        }
                        .padding(.horizontal, viewportCenterX - 120)
                        .padding(.top, topPadding)
                        .padding(.bottom, 20)
                    }
                    .onPreferenceChange(CardCenterKey.self) { centers in
                        // 居中动画期间焦点已锁定目标卡，避免中途“最近卡”抢焦点致放大闪烁。
                        guard !scrollLock else { return }
                        let ordered = (0..<items.count).map { centers[$0] ?? .infinity }
                        if let i = CarouselFocus.nearestIndex(cardCentersX: ordered,
                                                              viewportCenterX: viewportCenterX),
                           i != focusIndex {
                            focusIndex = i
                        }
                    }
                    .onMoveCommand { direction in
                        switch direction {
                        case .left:
                            step(-1, proxy: proxy)
                        case .right:
                            step(1, proxy: proxy)
                        default:
                            break
                        }
                    }
                    .overlay(alignment: .bottom) { dots }
                }
            }
        }
        .focusable()
    }

    // MARK: 卡片

    @ViewBuilder
    private func card(_ idx: Int, _ item: ShelfItem, proxy: ScrollViewProxy) -> some View {
        let focused = idx == focusIndex
        let members: [ScannedMember] = {
            if case .coding(let url) = item {
                return state.members(in: url)
            }
            return []
        }()
        ShelfCard(item: item, focused: focused, members: members, reduceMotion: reduceMotion)
            // 未居中的卡：先滑到中央聚焦；已居中的卡：再点才进入领域。
            .onTapGesture { focused ? enter(item) : centerCard(idx, proxy: proxy) }
    }

    /// 点击未居中卡：滑到中央并聚焦。复用 hover 的锁，避免居中动画期间被抢焦点闪烁。
    private func centerCard(_ idx: Int, proxy: ScrollViewProxy) {
        guard idx != focusIndex else { return }
        focusIndex = idx
        scrollLock = true
        scrollGen += 1
        let generation = scrollGen
        withAnimation(reduceMotion ? nil : Motion.carousel) {
            proxy.scrollTo(idx, anchor: .center)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(620))
            if generation == scrollGen {
                scrollLock = false
            }
        }
    }

    private func reporter(_ idx: Int) -> some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: CardCenterKey.self,
                value: [idx: geometry.frame(in: .global).midX]
            )
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<items.count, id: \.self) { index in
                Capsule()
                    .fill(index == focusIndex ? Color.lightBlue : Color.white.opacity(0.20))
                    .frame(width: index == focusIndex ? 18 : 6, height: 6)
                    .animation(reduceMotion ? nil : Motion.dropZone, value: focusIndex)
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: 动作

    private func step(_ delta: Int, proxy: ScrollViewProxy) {
        let next = CarouselFocus.clampedIndex(focusIndex + delta, count: items.count)
        focusIndex = next
        withAnimation(reduceMotion ? nil : Motion.domain) {
            proxy.scrollTo(next, anchor: .center)
        }
    }

    private func enter(_ item: ShelfItem) {
        switch item {
        case .coding(let url):
            withAnimation(reduceMotion ? nil : Motion.domain) {
                state.route = .codingSpace(url)
            }
        case .newSpace:
            state.createCodingSpace()
        }
    }
}

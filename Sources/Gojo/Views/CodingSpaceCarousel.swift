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
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 42)

            GeometryReader { geo in
                let viewportCenterX = geo.size.width / 2
                // 卡片滚动区与圆点区分配独立高度，极窄高度下也不会互相覆盖。
                let dotAreaHeight: CGFloat = 26
                let cardAreaHeight = max(0, geo.size.height - dotAreaHeight)
                let metrics = CarouselCardMetrics.calculate(
                    viewportWidth: geo.size.width,
                    availableHeight: cardAreaHeight
                )
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: metrics.spacing) {
                                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                                    card(idx, item, proxy: proxy, metrics: metrics)
                                        .id(idx)
                                        .background(reporter(idx))
                                }
                            }
                            .frame(minHeight: cardAreaHeight)
                            .padding(.horizontal, metrics.horizontalInset)
                        }
                        .frame(height: cardAreaHeight)

                        dots.frame(height: dotAreaHeight)
                    }
                    .focusable()
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
                }
            }
        }
    }

    // MARK: 卡片

    @ViewBuilder
    private func card(
        _ idx: Int,
        _ item: ShelfItem,
        proxy: ScrollViewProxy,
        metrics: CarouselCardMetrics
    ) -> some View {
        let focused = idx == focusIndex
        let members: [ScannedMember] = {
            if case .coding(let url) = item {
                return state.members(in: url)
            }
            return []
        }()
        Button {
            // 未居中的卡：先滑到中央聚焦；已居中的卡：再激活才进入领域。
            focused ? enter(item) : centerCard(idx, proxy: proxy)
        } label: {
            ShelfCard(
                item: item,
                focused: focused,
                focusedSize: metrics.focusedSize,
                sideSize: metrics.sideSize,
                members: members,
                reduceMotion: reduceMotion
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: item))
        .accessibilityValue(focused ? "已居中" : "未居中")
        .accessibilityHint(accessibilityHint(for: item, focused: focused))
    }

    /// 点击未居中卡：滑到中央并聚焦。复用 hover 的锁，避免居中动画期间被抢焦点闪烁。
    private func centerCard(_ idx: Int, proxy: ScrollViewProxy) {
        guard idx != focusIndex else { return }
        focusIndex = idx
        scrollLock = true
        scrollGen += 1
        let generation = scrollGen
        guard !reduceMotion else {
            proxy.scrollTo(idx, anchor: .center)
            DispatchQueue.main.async {
                if generation == scrollGen {
                    scrollLock = false
                }
            }
            return
        }
        withAnimation(Motion.carousel) {
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
                    .fill(index == focusIndex ? Color.lightBlue : Color.cardStroke)
                    .frame(width: index == focusIndex ? 18 : 6, height: 6)
                    .animation(reduceMotion ? nil : Motion.dropZone, value: focusIndex)
            }
        }
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

    private func accessibilityLabel(for item: ShelfItem) -> String {
        switch item {
        case .coding(let url):
            return "编码空间，\(url.lastPathComponent)"
        case .newSpace:
            return "新建编码空间"
        }
    }

    private func accessibilityHint(for item: ShelfItem, focused: Bool) -> String {
        switch (item, focused) {
        case (.coding, true):
            return "打开编码空间"
        case (.coding, false):
            return "先居中；再次激活可打开编码空间"
        case (.newSpace, true):
            return "创建编码空间"
        case (.newSpace, false):
            return "先居中；再次激活可创建编码空间"
        }
    }
}

import SwiftUI
import GojoCore

/// 各卡中心 x 的 PreferenceKey：卡片通过 GeometryReader 上报，容器据此算焦点。
private struct CardCenterKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 展示柜：焦点轮播首页。公共空间卡（首位）+ N 编码空间卡 + 新建卡（末位）。
struct ShelfView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var focusIndex = 0

    private var items: [ShelfItem] {
        [.publicSpace] + state.codingSpaces.map(ShelfItem.coding) + [.newSpace]
    }

    var body: some View {
        GeometryReader { geo in
            let viewportCenterX = geo.size.width / 2
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                            card(idx, item)
                                .id(idx)
                                .background(reporter(idx))
                        }
                    }
                    .padding(.horizontal, viewportCenterX - 120)
                    .padding(.vertical, 40)
                }
                .onPreferenceChange(CardCenterKey.self) { centers in
                    let ordered = (0..<items.count).map { centers[$0] ?? .infinity }
                    if let i = CarouselFocus.nearestIndex(cardCentersX: ordered,
                                                          viewportCenterX: viewportCenterX) {
                        if i != focusIndex { focusIndex = i }
                    }
                }
                .onMoveCommand { direction in
                    switch direction {
                    case .left:  step(-1, proxy: proxy)
                    case .right: step(1, proxy: proxy)
                    default: break
                    }
                }
                .overlay(alignment: .bottom) { dots }
            }
        }
        .background(DomainBackground())
        .focusable()
    }

    // MARK: 卡片

    @ViewBuilder
    private func card(_ idx: Int, _ item: ShelfItem) -> some View {
        let focused = idx == focusIndex
        let members: [ScannedMember] = {
            if case .coding(let u) = item { return state.members(in: u) }
            return []
        }()
        ShelfCard(item: item, focused: focused, members: members, reduceMotion: reduceMotion)
            .onTapGesture { enter(item) }
    }

    private func reporter(_ idx: Int) -> some View {
        GeometryReader { g in
            Color.clear.preference(key: CardCenterKey.self,
                                   value: [idx: g.frame(in: .global).midX])
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<items.count, id: \.self) { i in
                Capsule()
                    .fill(i == focusIndex ? Color.lightBlue : Color.white.opacity(0.22))
                    .frame(width: i == focusIndex ? 18 : 6, height: 6)
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
        case .publicSpace:
            withAnimation(reduceMotion ? nil : Motion.domain) { state.route = .publicSpace }
        case .coding(let u):
            withAnimation(reduceMotion ? nil : Motion.domain) { state.route = .codingSpace(u) }
        case .newSpace:
            state.createCodingSpace()
        }
    }
}

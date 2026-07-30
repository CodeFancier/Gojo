import SwiftUI
import GojoCore

/// 展示柜里的一项：公共空间（首位）、编码空间、新建卡（末位）。
enum ShelfItem: Hashable {
    case publicSpace
    case coding(URL)
    case newSpace
}

/// 展示柜卡片。焦点态放大发光 + 成员缩略墙；侧卡态缩小去饱和只留名字。
struct ShelfCard: View {
    let item: ShelfItem
    let focused: Bool
    /// 编码空间成员（仅 .coding 用）
    var members: [ScannedMember] = []
    var reduceMotion: Bool = false

    @State private var breathe = false

    private var title: String {
        switch item {
        case .publicSpace: return "公共空间"
        case .coding(let u): return u.lastPathComponent
        case .newSpace: return "新建编码空间"
        }
    }

    var body: some View {
        Group {
            switch item {
            case .newSpace: newCard
            default:        spaceCard
            }
        }
        .frame(width: focused ? 240 : 150, height: focused ? 200 : 150)
        .scaleEffect(focused ? 1 : 0.9)
        .opacity(focused ? 1 : 0.42)
        .saturation(focused ? 1 : 0.5)
        .offset(y: (focused && breathe && !reduceMotion) ? -4 : 0)
        .animation(reduceMotion ? nil : Motion.domain, value: focused)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Motion.breathe) { breathe = true }
        }
    }

    // MARK: 空间卡（公共空间 / 编码空间）

    private var spaceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: item == .publicSpace ? "globe" : "shippingbox.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(item == .publicSpace ? Color.lightBlue : Color(white: 0.85))
                Text(title)
                    .font(.system(size: focused ? 17 : 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            if focused {
                subtitle
                if case .coding = item { thumbnailWall }
                Spacer(minLength: 0)
            }
        }
        .padding(focused ? 16 : 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: focused ? Color.coreBlue.opacity(0.45) : .clear,
                radius: focused ? 22 : 0, y: 8)
    }

    @ViewBuilder private var subtitle: some View {
        switch item {
        case .coding:
            Text("\(members.count) 个仓库")
                .font(.system(size: 11.5)).foregroundStyle(Color(white: 0.6))
        case .publicSpace:
            Text("拖项目到编码空间使用")
                .font(.system(size: 11.5)).foregroundStyle(Color(white: 0.6))
        case .newSpace:
            EmptyView()
        }
    }

    /// 成员缩略墙：图标 + 文件夹名小胶囊，超出收 +N。
    private var thumbnailWall: some View {
        let maxShown = 4
        let shown = members.prefix(maxShown)
        let extra = members.count - shown.count
        return FlowRow(spacing: 5) {
            ForEach(Array(shown), id: \.folderName) { m in
                HStack(spacing: 4) {
                    SourceBadgeIcon(kind: SourceIconKind(m.form), size: 14,
                                    badgeBackground: Color(white: 0.16))
                    Text(m.folderName)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color(white: 0.78))
                        .lineLimit(1)
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.white.opacity(0.06), in: Capsule())
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color(white: 0.6))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }
        }
    }

    // MARK: 新建卡

    private var newCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: focused ? 30 : 22, weight: .semibold))
                .foregroundStyle(Color.lightBlue)
            if focused {
                Text("新建编码空间")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(Color.lightBlue.opacity(focused ? 0.6 : 0.3)))
    }

    // MARK: 装饰

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(focused
                  ? LinearGradient(colors: [Color.coreBlue.opacity(0.16), Color.white.opacity(0.05)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                  : LinearGradient(colors: [Color.white.opacity(0.055), Color.white.opacity(0.055)],
                                   startPoint: .top, endPoint: .bottom))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(focused ? Color.lightBlue.opacity(0.45) : Color.white.opacity(0.10),
                          lineWidth: 1)
    }
}

/// 简易流式换行布局，用于成员缩略墙。
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += sz.width + spacing
            rowHeight = max(rowHeight, sz.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += sz.width + spacing
            rowHeight = max(rowHeight, sz.height)
        }
    }
}

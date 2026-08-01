import SwiftUI
import GojoCore

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
        case .coding(let url): return url.lastPathComponent
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

    // MARK: 编码空间卡

    private var spaceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.textSecondary)
            }
            if focused {
                subtitle
                thumbnailWall
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

    private var subtitle: some View {
        Text("\(members.count) 个仓库")
            .font(.subheadline)
            .foregroundStyle(Color.textTertiary)
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
                                    badgeBackground: Color.chrome)
                    Text(m.folderName)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.surface, in: Capsule())
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.surface, in: Capsule())
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
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.surface))
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
                  : LinearGradient(colors: [Color.surface, Color.surface],
                                   startPoint: .top, endPoint: .bottom))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(focused ? Color.lightBlue.opacity(0.45) : Color.cardStroke,
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

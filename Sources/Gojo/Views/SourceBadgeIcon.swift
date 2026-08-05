import SwiftUI
import GojoCore

/// 统一底图 + 右下角来源角标。形态切换时只有角标动，底图不动。
/// 角标外圈描边取 badgeBackground（所在容器背景同色），保证任意材质上都能切出边界。
struct SourceBadgeIcon: View {
    let kind: SourceIconKind
    var size: CGFloat = 22
    var badgeBackground: Color = .domainBGBottom

    private var badgeSize: CGFloat { max(10, size * 0.5) }

    var body: some View {
        Image(systemName: kind.baseSymbol)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(Color.textSecondary)
            .frame(width: size, height: size)
            .overlay(alignment: .bottomTrailing) {
                if let badge = kind.badgeSymbol {
                    Image(systemName: badge)
                        .font(.system(size: badgeSize * 0.6, weight: .bold))
                        .foregroundStyle(Color.deepInk)
                        .frame(width: badgeSize, height: badgeSize)
                        .background(Color.badge(kind.badgeColorName), in: Circle())
                        .overlay(Circle().strokeBorder(badgeBackground, lineWidth: badgeSize * 0.14))
                        .offset(x: badgeSize * 0.3, y: badgeSize * 0.22)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: kind)
    }
}

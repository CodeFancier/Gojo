import SwiftUI

/// 动画常量集中一处；reduceMotion 打开时调用方传 nil 退化为无动画/交叉淡入。
enum Motion {
    static let domain: Animation = .spring(response: 0.42, dampingFraction: 0.82)
    static let badge: Animation = .easeInOut(duration: 0.2)
    static let dropZone: Animation = .easeInOut(duration: 0.18)
    /// 展示柜 hover 跟随：把悬停的卡"慢慢"滑向中央，比 domain 更柔更慢。
    static let carousel: Animation = .spring(response: 0.55, dampingFraction: 0.9)
    static let breathe: Animation = .easeInOut(duration: 3.6).repeatForever(autoreverses: true)

    /// 成员网格错峰浮现：每张卡 0.08s 步进延迟。
    static func gridStagger(_ i: Int) -> Double { Double(i) * 0.08 }
}

/// 品牌四色，不引入新色。
extension Color {
    static let coreBlue  = Color(red: 59/255,  green: 130/255, blue: 246/255) // #3B82F6
    static let lightBlue = Color(red: 96/255,  green: 165/255, blue: 250/255) // #60A5FA
    static let publicTeal = Color(red: 45/255, green: 212/255, blue: 191/255)
    static let publicSurface = Color(red: 13/255, green: 148/255, blue: 136/255).opacity(0.22)
    static let publicStroke = Color.publicTeal.opacity(0.42)
    static let warmAmber = Color(red: 217/255, green: 149/255, blue: 88/255)  // Claude 强调色
    static let deepInk   = Color(red: 17/255,  green: 24/255,  blue: 39/255)  // #111827

    /// 深色渐变底 #0C1424 → #16213A。
    static let domainBGTop    = Color(red: 22/255, green: 33/255, blue: 58/255) // #16213A
    static let domainBGBottom = Color(red: 12/255, green: 20/255, blue: 36/255) // #0C1424

    /// 顶栏/托盘等外框 chrome 底色 #141E34，落在渐变 top/bottom 之间，
    /// 让"边框"与"中央"同色系，取代会在深色内容上泛白的 .ultraThinMaterial。
    static let chrome = Color(red: 20/255, green: 30/255, blue: 52/255) // #141E34

    // MARK: 语义中性文本（微冷调，与深蓝底同色温；取代散落的 Color(white:) 纯灰）
    /// 标题/名称等主文本。纯白保证最高对比。
    static let textPrimary   = Color.white
    /// 次级文本：标签、图标、较突出的副信息。≈ white 0.82，偏冷。
    static let textSecondary = Color(red: 0.80, green: 0.83, blue: 0.90)
    /// 三级文本：说明、描述、副标题、计数。≈ white 0.64，偏冷。
    static let textTertiary  = Color(red: 0.62, green: 0.67, blue: 0.76)
    /// 弱文本：占位提示、URL。≈ white 0.52，偏冷（较旧 0.45 更亮，改善对比度）。
    static let textMuted     = Color(red: 0.50, green: 0.55, blue: 0.64)

    // MARK: 表面与描边（收敛散落的白色叠加档位）
    /// 卡片/行填充。
    static let surface    = Color.white.opacity(0.06)
    /// 卡片/胶囊描边。
    static let cardStroke = Color.white.opacity(0.10)
    /// 顶栏/托盘底部发丝分隔线。
    static let hairline   = Color.white.opacity(0.08)

    /// 角标底色名 → 色；nil 或未知返回 clear。
    static func badge(_ name: String?) -> Color {
        switch name {
        case "coreBlue":  return .coreBlue
        case "lightBlue": return .lightBlue
        default:          return .clear
        }
    }
}

/// 领域深色渐变背景。
struct DomainBackground: View {
    var body: some View {
        LinearGradient(colors: [.domainBGTop, .domainBGBottom],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

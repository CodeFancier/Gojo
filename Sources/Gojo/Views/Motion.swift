import SwiftUI

/// 动画常量集中一处；reduceMotion 打开时调用方传 nil 退化为无动画/交叉淡入。
enum Motion {
    static let domain: Animation = .spring(response: 0.42, dampingFraction: 0.82)
    static let badge: Animation = .easeInOut(duration: 0.2)
    static let dropZone: Animation = .easeInOut(duration: 0.18)
    static let breathe: Animation = .easeInOut(duration: 3.6).repeatForever(autoreverses: true)

    /// 成员网格错峰浮现：每张卡 0.08s 步进延迟。
    static func gridStagger(_ i: Int) -> Double { Double(i) * 0.08 }
}

/// 品牌四色，不引入新色。
extension Color {
    static let coreBlue  = Color(red: 59/255,  green: 130/255, blue: 246/255) // #3B82F6
    static let lightBlue = Color(red: 96/255,  green: 165/255, blue: 250/255) // #60A5FA
    static let deepInk   = Color(red: 17/255,  green: 24/255,  blue: 39/255)  // #111827
    static let slate     = Color(red: 55/255,  green: 65/255,  blue: 81/255)  // #374151

    /// 深色渐变底 #0C1424 → #16213A。
    static let domainBGTop    = Color(red: 22/255, green: 33/255, blue: 58/255) // #16213A
    static let domainBGBottom = Color(red: 12/255, green: 20/255, blue: 36/255) // #0C1424

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

import SwiftUI

/// 首页品牌字标：从 bundle 资源加载 Gojo 字标 PNG；加载失败时文字兜底，绝不开天窗。
struct BrandWordmark: View {
    var height: CGFloat = 30

    var body: some View {
        Group {
            if let img = Self.image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
            } else {
                Text("Gojo")
                    .font(.system(size: height * 0.8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel("Gojo")
    }

    /// 只解码一次。打包 .app 从 Contents/Resources 取（Bundle.main）；
    /// debug 裸二进制从 SwiftPM 资源 bundle 取（Bundle.module）。
    private static let image: NSImage? = {
        let name = "gojo-wordmark", ext = "png"
        let url = Bundle.main.url(forResource: name, withExtension: ext)
                ?? Bundle.module.url(forResource: name, withExtension: ext)
        guard let url, let img = NSImage(contentsOf: url) else { return nil }
        return img
    }()
}

/// 作者署名，弱化处理，置于首页角落。
struct AuthorCredit: View {
    var body: some View {
        Text("by FancyJ")
            .font(.caption)
            .foregroundStyle(Color.textMuted)
            .accessibilityLabel("作者 FancyJ")
    }
}

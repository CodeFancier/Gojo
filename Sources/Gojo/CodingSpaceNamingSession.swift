import Foundation

/// 首页「新建编码空间」在根目录已设置时弹出的命名会话。
struct CodingSpaceNamingSession: Identifiable {
    let id = UUID()
    var name: String = ""
}

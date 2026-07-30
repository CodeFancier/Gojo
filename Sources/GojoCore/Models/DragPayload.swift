import Foundation

/// 拖拽 payload 的编解码。
/// 成员 payload 为三行文本，首行哨兵，避免与公共项目的裸 UUID 串混淆；
/// 公共项目 payload 即其 id 的 uuidString（含换行的成员格式天然不是合法 UUID）。
public enum DragPayload {
    private static let memberPrefix = "gojo-member"

    public static func member(space: URL, folder: String) -> String {
        "\(memberPrefix)\n\(space.path)\n\(folder)"
    }

    /// 解析成员 payload；非成员格式返回 nil。
    public static func parseMember(_ s: String) -> (space: URL, folder: String)? {
        let parts = s.components(separatedBy: "\n")
        guard parts.count == 3, parts[0] == memberPrefix else { return nil }
        return (URL(fileURLWithPath: parts[1]), parts[2])
    }

    public static func publicProject(_ id: UUID) -> String {
        id.uuidString
    }

    public static func parsePublicProject(_ s: String) -> UUID? {
        UUID(uuidString: s)
    }
}

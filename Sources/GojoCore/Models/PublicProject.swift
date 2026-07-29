import Foundation

public struct PublicProject: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var url: String
    /// 是否已在公共空间本地克隆
    public var cloned: Bool

    public init(id: UUID = UUID(), name: String, url: String, cloned: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.cloned = cloned
    }
}

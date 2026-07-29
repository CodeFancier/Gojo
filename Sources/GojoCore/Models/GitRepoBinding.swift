import Foundation

public struct GitRepoBinding: Codable, Identifiable, Hashable {
    public var id: UUID
    public var url: String
    /// 相对开发项目根目录的子目录名
    public var subdirectory: String
    /// 最近一次已知分支
    public var branch: String?

    public init(id: UUID = UUID(), url: String, subdirectory: String, branch: String? = nil) {
        self.id = id
        self.url = url
        self.subdirectory = subdirectory
        self.branch = branch
    }
}

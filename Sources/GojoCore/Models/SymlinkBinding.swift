import Foundation

public struct SymlinkBinding: Codable, Identifiable, Hashable {
    public var id: UUID
    /// 公共空间下的共享库文件夹名
    public var publicRepoName: String
    /// 相对开发项目根目录的链接路径（链接文件名）
    public var linkPath: String

    public init(id: UUID = UUID(), publicRepoName: String, linkPath: String) {
        self.id = id
        self.publicRepoName = publicRepoName
        self.linkPath = linkPath
    }
}

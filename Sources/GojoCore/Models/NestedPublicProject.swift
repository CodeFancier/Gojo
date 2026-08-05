import Foundation

/// 复合公共文件夹中的直接子级 Git 仓库。
public struct NestedPublicProject: Identifiable, Hashable {
    public var parentRelativePath: String
    public var name: String
    public var url: String
    public var publicProjectID: UUID?

    public var id: String { "\(parentRelativePath)/\(name)" }
    public var isPromoted: Bool { publicProjectID != nil }
    public var parentFolderName: String {
        URL(fileURLWithPath: parentRelativePath).lastPathComponent
    }

    public init(parentRelativePath: String, name: String, url: String,
                publicProjectID: UUID? = nil) {
        self.parentRelativePath = parentRelativePath
        self.name = name
        self.url = url
        self.publicProjectID = publicProjectID
    }

    public init(parentFolderName: String, name: String, url: String,
                publicProjectID: UUID? = nil) {
        self.init(parentRelativePath: parentFolderName, name: name, url: url,
                  publicProjectID: publicProjectID)
    }
}

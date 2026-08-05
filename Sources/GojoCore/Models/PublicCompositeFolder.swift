import Foundation

/// 公共空间中可以展开并扫描直接子级 Git 仓库的目录。
public struct PublicCompositeFolder: Identifiable, Hashable {
    public var name: String
    public var relativePath: String
    public var publicProjectID: UUID?
    public var projects: [NestedPublicProject]

    public var id: String { relativePath }
    public var isPublicProject: Bool { publicProjectID != nil }

    public init(name: String, relativePath: String? = nil,
                publicProjectID: UUID? = nil, projects: [NestedPublicProject]) {
        self.name = name
        self.relativePath = relativePath ?? name
        self.publicProjectID = publicProjectID
        self.projects = projects
    }
}

import Foundation

public struct WorkspaceManifest: Codable, Equatable {
    public var name: String
    /// 开发项目文件夹名（相对编码空间根）
    public var projectDirectories: [String]

    public init(name: String, projectDirectories: [String] = []) {
        self.name = name
        self.projectDirectories = projectDirectories
    }
}

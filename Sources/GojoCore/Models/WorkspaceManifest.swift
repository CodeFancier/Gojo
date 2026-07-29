import Foundation

public struct WorkspaceManifest: Codable, Equatable {
    public var name: String
    /// 仅绑定了公共项目的成员；独立仓库靠扫描发现，不在此列。
    public var members: [WorkspaceMember]

    public init(name: String, members: [WorkspaceMember] = []) {
        self.name = name
        self.members = members
    }
}

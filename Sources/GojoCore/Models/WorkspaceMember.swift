import Foundation

/// 仅记录「绑定了公共项目」的成员；独立仓库不入清单。
public struct WorkspaceMember: Codable, Identifiable, Hashable {
    public var id: UUID
    /// 编码空间内的直接子文件夹名
    public var folderName: String
    /// 来源公共项目 id
    public var publicProjectId: UUID
    public var mode: MemberMode

    public init(id: UUID = UUID(), folderName: String,
                publicProjectId: UUID, mode: MemberMode) {
        self.id = id
        self.folderName = folderName
        self.publicProjectId = publicProjectId
        self.mode = mode
    }
}

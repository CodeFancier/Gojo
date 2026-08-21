import Foundation

/// 公共空间列表的一个条目：根下直接子目录，或清单登记项（可能尚未克隆落盘）。
public struct PublicSpaceEntry: Identifiable, Hashable {
    public var name: String
    public var relativePath: String
    /// 目录是否已在磁盘上（未克隆的登记项为 false）。
    public var isOnDisk: Bool
    /// 自身含 .git（仅 isOnDisk 时有意义）。
    public var isGitRepository: Bool
    /// 自身 origin 远程地址；无 origin 或非 git 为空串。
    public var remoteURL: String
    public var publicProjectID: UUID?
    public var projects: [NestedPublicProject]

    public var id: String { relativePath }

    public init(name: String, relativePath: String? = nil, isOnDisk: Bool = true,
                isGitRepository: Bool = false, remoteURL: String = "",
                publicProjectID: UUID? = nil, projects: [NestedPublicProject] = []) {
        self.name = name
        self.relativePath = relativePath ?? name
        self.isOnDisk = isOnDisk
        self.isGitRepository = isGitRepository
        self.remoteURL = remoteURL
        self.publicProjectID = publicProjectID
        self.projects = projects
    }
}

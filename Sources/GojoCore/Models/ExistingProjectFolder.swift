import Foundation

/// 编码空间根目录下的一个已存在文件夹，可原位登记为独立编码空间。
public struct ExistingProjectFolder: Identifiable, Hashable, Sendable {
    /// 用真实路径作唯一标识
    public let id: String
    /// 文件夹原位路径
    public let url: URL
    /// 是否为 git 仓库（仅作展示徽标，不影响可登记性）
    public let isGitRepository: Bool

    public var name: String { url.lastPathComponent }

    public init(url: URL, isGitRepository: Bool) {
        self.id = url.path
        self.url = url
        self.isGitRepository = isGitRepository
    }
}

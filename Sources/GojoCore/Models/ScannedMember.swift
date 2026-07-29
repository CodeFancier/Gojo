import Foundation

/// 编码空间成员的运行态形态（扫描得到，不落盘）。
public enum MemberForm: Hashable {
    case standalone              // 含 .git、未绑定公共项目
    case publicGit(UUID)         // 含 .git、绑定公共项目（Git 模式）
    case publicSymlink(UUID)     // 符号链接指向公共项目
}

public struct ScannedMember: Identifiable, Hashable {
    public var folderName: String
    /// git 仓库实时分支；读不到为 nil
    public var branch: String?
    public var form: MemberForm

    public var id: String { folderName }

    public init(folderName: String, form: MemberForm, branch: String?) {
        self.folderName = folderName
        self.form = form
        self.branch = branch
    }
}

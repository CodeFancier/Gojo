import Foundation

/// 成员/公共项目的来源图标语义：统一底图 + 来源角标。
/// 不直接用 MemberForm，因为托盘里的公共项目还不是成员（无 MemberForm 可言）。
public enum SourceIconKind: Equatable {
    case standalone       // 独立仓库
    case publicGit        // 公共项目·Git 克隆
    case publicSymlink    // 公共项目·软链接
    case unjoinedPublic   // 托盘里未加入的公共项目

    public init(_ form: MemberForm) {
        switch form {
        case .standalone: self = .standalone
        case .publicGit: self = .publicGit
        // 外部软链接与公共项目软链接同属「软链接」语义，共用 link 角标。
        case .publicSymlink, .externalSymlink: self = .publicSymlink
        }
    }

    /// 底图 SF Symbol。
    public var baseSymbol: String {
        switch self {
        case .standalone, .publicGit, .publicSymlink: return "shippingbox"
        case .unjoinedPublic:                         return "globe"
        }
    }

    /// 右下角来源角标 SF Symbol；无角标为 nil。
    public var badgeSymbol: String? {
        switch self {
        case .publicGit:     return "arrow.triangle.branch"
        case .publicSymlink: return "link"
        case .standalone, .unjoinedPublic: return nil
        }
    }

    /// 角标底色名（对应品牌色扩展）；无角标为 nil。
    public var badgeColorName: String? {
        switch self {
        case .publicGit:     return "coreBlue"
        case .publicSymlink: return "lightBlue"
        case .standalone, .unjoinedPublic: return nil
        }
    }
}

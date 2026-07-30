import Foundation

/// 单窗口路由状态机。同一时刻只呈现一个 Route。
public enum Route: Hashable {
    case shelf                                          // 展示柜（首页）
    case publicSpace                                    // 公共空间领域
    case codingSpace(URL)                               // 编码空间领域
    case shelfDropping(source: URL, folder: String)     // 投放模式：展示柜叠在源领域之上

    /// 领域对应的文件夹 URL；仅 codingSpace 直接持有，其余需外部（用 manager）求值。
    public var domainFolder: URL? {
        switch self {
        case .codingSpace(let u): return u
        case .shelf, .publicSpace, .shelfDropping: return nil
        }
    }

    /// 从展示柜进入某个领域。合法则返回目标，否则原地不动。
    public func entering(_ target: Route) -> Route {
        switch (self, target) {
        case (.shelf, .publicSpace), (.shelf, .codingSpace):
            return target
        default:
            return self
        }
    }

    /// 返回：任意领域 → 展示柜；投放模式 → 回到源编码空间（拖拽取消）；展示柜 → 原地。
    public func back() -> Route {
        switch self {
        case .shelfDropping(let source, _): return .codingSpace(source)
        case .publicSpace, .codingSpace:    return .shelf
        case .shelf:                        return .shelf
        }
    }

    /// 进入投放模式：仅编码空间可发起。
    public func beginDropping(folder: String) -> Route? {
        switch self {
        case .codingSpace(let u): return .shelfDropping(source: u, folder: folder)
        default:                  return nil
        }
    }
}

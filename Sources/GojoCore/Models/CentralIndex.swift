import Foundation

public enum TerminalApp: String, Codable, CaseIterable {
    case terminal, iterm2, warp
}

public extension TerminalApp {
    /// 菜单里显示的名字。
    var displayName: String {
        switch self {
        case .terminal: return "Terminal"
        case .iterm2: return "iTerm2"
        case .warp: return "Warp"
        }
    }

    /// 候选 bundle id，按优先级排列。open -b 按 bundle id 唤起，不受应用
    /// 本地名影响（如 brew 装 warp@preview 时应用名是 WarpPreview.app）。
    var bundleIDs: [String] {
        switch self {
        case .terminal: return ["com.apple.Terminal"]
        case .iterm2: return ["com.googlecode.iterm2"]
        case .warp: return ["dev.warp.Warp-Stable", "dev.warp.Warp-Preview"]
        }
    }

    /// open -a 回退链：bundle id 全部未命中时按应用名找。
    var appNames: [String] {
        switch self {
        case .terminal: return ["Terminal"]
        case .iterm2: return ["iTerm", "iTerm2"]
        case .warp: return ["Warp", "WarpPreview"]
        }
    }
}

public struct CentralIndex: Codable, Equatable {
    public var publicSpacePath: String?
    public var codingSpacePaths: [String]
    public var terminalPreference: TerminalApp

    public init(publicSpacePath: String? = nil,
                codingSpacePaths: [String] = [],
                terminalPreference: TerminalApp = .terminal) {
        self.publicSpacePath = publicSpacePath
        self.codingSpacePaths = codingSpacePaths
        self.terminalPreference = terminalPreference
    }
}

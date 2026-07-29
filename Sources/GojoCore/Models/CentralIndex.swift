import Foundation

public enum TerminalApp: String, Codable, CaseIterable {
    case terminal, iterm2, warp
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

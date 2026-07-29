import Foundation

public enum ExternalApp: Equatable {
    case finder
    case terminal(TerminalApp)
}

public struct LaunchSpec: Equatable {
    public let executable: String
    public let arguments: [String]
    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public struct ExternalAppLauncher {
    private let shell: ShellRunner
    public init(shell: ShellRunner = ShellRunner()) { self.shell = shell }

    public func launchSpec(for app: ExternalApp, path: URL) -> LaunchSpec {
        switch app {
        case .finder:
            return LaunchSpec(executable: "open", arguments: [path.path])
        case .terminal(let term):
            let appName: String
            switch term {
            case .terminal: appName = "Terminal"
            case .iterm2:   appName = "iTerm"
            case .warp:     appName = "Warp"
            }
            return LaunchSpec(executable: "open", arguments: ["-a", appName, path.path])
        }
    }

    public func launch(_ app: ExternalApp, path: URL) throws {
        let spec = launchSpec(for: app, path: path)
        _ = try shell.run(spec.executable, spec.arguments)
    }
}

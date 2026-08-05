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

    // MARK: 在终端里 resume 助手会话

    private func appName(_ term: TerminalApp) -> String {
        switch term {
        case .terminal: return "Terminal"
        case .iterm2:   return "iTerm"
        case .warp:     return "Warp"
        }
    }

    private func resumeArgs(_ kind: AgentKind, sessionId: String) -> String {
        // 会话 id 为 UUID，仍单引号包裹以防意外。
        let id = "'" + sessionId.replacingOccurrences(of: "'", with: "'\\''") + "'"
        switch kind {
        case .claude: return "claude --resume \(id)"
        case .codex:  return "codex resume \(id)"
        }
    }

    /// 生成 .command 脚本内容：source 用户 profile 保证 PATH，cd 到项目再 resume。
    public func resumeScript(_ kind: AgentKind, sessionId: String, cwd: URL) -> String {
        let dir = "'" + cwd.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return """
        #!/bin/zsh
        [ -f ~/.zprofile ] && source ~/.zprofile
        [ -f ~/.zshrc ] && source ~/.zshrc
        cd \(dir) || exit 1
        \(resumeArgs(kind, sessionId: sessionId))
        """
    }

    /// 把 resume 脚本写入临时 .command 并用偏好终端打开执行。
    public func resume(_ kind: AgentKind, sessionId: String, cwd: URL,
                       terminal: TerminalApp) throws {
        let script = resumeScript(kind, sessionId: sessionId, cwd: cwd)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gojo-resume-\(kind.rawValue)-\(sessionId).command")
        try script.write(to: tmp, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: tmp.path)
        _ = try shell.run("open", ["-a", appName(terminal), tmp.path])
    }
}

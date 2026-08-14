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

/// 终端候选全部未命中时抛出。
public struct TerminalLaunchError: LocalizedError {
    public let terminal: TerminalApp
    public init(_ terminal: TerminalApp) { self.terminal = terminal }
    public var errorDescription: String? {
        "未找到终端应用：\(terminal.displayName)（可先安装或换用其他终端）"
    }
}

public struct ExternalAppLauncher {
    /// ShellRunner 非零退出码不会 throw，回退链要靠 exitCode 判断成败，
    /// 这里抽成闭包便于测试注入。
    private let run: (String, [String]) throws -> ShellResult

    public init(shell: ShellRunner = ShellRunner()) {
        self.run = { try shell.run($0, $1) }
    }

    /// 测试注入口。
    public init(run: @escaping (String, [String]) throws -> ShellResult) {
        self.run = run
    }

    /// 首选唤起方式；实际 launch 会沿候选链回退，这里只暴露第一步。
    public func launchSpec(for app: ExternalApp, path: URL) -> LaunchSpec {
        switch app {
        case .finder:
            return LaunchSpec(executable: "open", arguments: [path.path])
        case .terminal(let term):
            return LaunchSpec(executable: "open", arguments: ["-b", term.bundleIDs[0], path.path])
        }
    }

    public func launch(_ app: ExternalApp, path: URL) throws {
        switch app {
        case .finder:
            _ = try run("open", [path.path])
        case .terminal(let term):
            try openInTerminal(term, target: path.path)
        }
    }

    /// 依次尝试 bundle id 与应用名：兼容同一终端的多个发行版
    /// （如 Warp stable 是 Warp.app、warp@preview 是 WarpPreview.app）。
    private func openInTerminal(_ term: TerminalApp, target: String) throws {
        let attempts: [[String]] =
            term.bundleIDs.map { ["-b", $0] } + term.appNames.map { ["-a", $0] }
        for args in attempts {
            if try run("open", args + [target]).exitCode == 0 { return }
        }
        throw TerminalLaunchError(term)
    }

    // MARK: 在终端里 resume 助手会话

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
        try openInTerminal(terminal, target: tmp.path)
    }
}

import Foundation

public enum GitError: Error, Equatable {
    case commandFailed(String)
}

public struct GitService {
    private let shell: ShellRunner
    public init(shell: ShellRunner = ShellRunner()) { self.shell = shell }

    @discardableResult
    private func git(_ args: [String], at dir: URL? = nil,
                     environment: [String: String] = [:]) throws -> String {
        let r = try shell.run("git", args, cwd: dir, environment: environment)
        guard r.exitCode == 0 else { throw GitError.commandFailed(r.stderr) }
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 网络操作的非交互环境：GUI 进程没有可交互的终端，git/ssh 一旦尝试索取
    /// 凭据或 host key 确认，子进程会停在提示上永不退出，界面就永远停在
    /// 「克隆中」。显式禁掉交互，让需要凭据的场景立刻失败并把 git 报错带回界面。
    private static let nonInteractiveEnv: [String: String] = [
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_ASKPASS": "/usr/bin/true",
        "SSH_ASKPASS": "/usr/bin/true",
        "SSH_ASKPASS_REQUIRE": "never",
    ]

    /// 网络黑洞兜底：60 秒内速度低于 1KB/s 即判失败。git 默认不设任何超时，
    /// 对端无响应时底层读会无限阻塞。注意 -c 须置于子命令之前——放在 clone
    /// 之后会被当作 `clone -c` 写进新仓库的 .git/config 残留下来。
    private static let networkArgs = [
        "-c", "http.lowSpeedLimit=1000", "-c", "http.lowSpeedTime=60",
    ]

    public func clone(url: String, into destination: URL) throws {
        try git(Self.networkArgs + ["clone", url, destination.path],
                environment: Self.nonInteractiveEnv)
    }

    public func currentBranch(at repo: URL) throws -> String {
        try git(["rev-parse", "--abbrev-ref", "HEAD"], at: repo)
    }

    public func listBranches(at repo: URL) throws -> [String] {
        let out = try git(["branch", "--all", "--format=%(refname:short)"], at: repo)
        var seen = Set<String>()
        var result: [String] = []

        for line in out.split(separator: "\n") {
            var branch = line.trimmingCharacters(in: .whitespaces)
            guard !branch.isEmpty else { continue }

            // Skip symbolic refs like "origin/HEAD -> origin/main"
            if branch.contains("->") {
                continue
            }

            // Strip "origin/" prefix from remote-tracking branches for consistency
            if branch.hasPrefix("origin/") {
                branch = String(branch.dropFirst(7))
            }

            // Add only if not seen before (order-preserving deduplication)
            if !seen.contains(branch) {
                seen.insert(branch)
                result.append(branch)
            }
        }

        return result
    }

    public func checkout(branch: String, at repo: URL) throws {
        try git(["checkout", branch], at: repo)
    }

    public func pull(at repo: URL) throws {
        try git(Self.networkArgs + ["pull", "--ff-only"], at: repo,
                environment: Self.nonInteractiveEnv)
    }

    /// 工作区有未提交改动（含未跟踪文件）。
    public func hasUncommittedChanges(at repo: URL) throws -> Bool {
        let out = try git(["status", "--porcelain"], at: repo)
        return !out.isEmpty
    }

    /// 有未推送到上游的提交；无上游按「有风险」处理（返回 true）。
    public func hasUnpushedCommits(at repo: URL) throws -> Bool {
        let upstream = try shell.run(
            "git", ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], cwd: repo)
        if upstream.exitCode != 0 { return true }   // 无上游 → 风险
        let log = try git(["log", "@{u}..HEAD", "--oneline"], at: repo)
        return !log.isEmpty
    }

    /// 读取 origin 远程 URL；无则抛错。
    public func remoteURL(at repo: URL) throws -> String {
        try git(["remote", "get-url", "origin"], at: repo)
    }
}

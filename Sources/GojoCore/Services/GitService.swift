import Foundation

public enum GitError: Error, Equatable {
    case commandFailed(String)
}

public struct GitService {
    private let shell: ShellRunner
    public init(shell: ShellRunner = ShellRunner()) { self.shell = shell }

    @discardableResult
    private func git(_ args: [String], at dir: URL? = nil) throws -> String {
        let r = try shell.run("git", args, cwd: dir)
        guard r.exitCode == 0 else { throw GitError.commandFailed(r.stderr) }
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func clone(url: String, into destination: URL) throws {
        try git(["clone", url, destination.path])
    }

    public func currentBranch(at repo: URL) throws -> String {
        try git(["rev-parse", "--abbrev-ref", "HEAD"], at: repo)
    }

    public func listBranches(at repo: URL) throws -> [String] {
        let out = try git(["branch", "--all", "--format=%(refname:short)"], at: repo)
        return out.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { branch in
                // Strip "origin/" prefix from remote-tracking branches for consistency
                if branch.hasPrefix("origin/") {
                    return String(branch.dropFirst(7))
                }
                return branch
            }
            .filter { $0 != "HEAD" }  // Filter out symbolic refs
    }

    public func checkout(branch: String, at repo: URL) throws {
        try git(["checkout", branch], at: repo)
    }

    public func pull(at repo: URL) throws {
        try git(["pull", "--ff-only"], at: repo)
    }
}

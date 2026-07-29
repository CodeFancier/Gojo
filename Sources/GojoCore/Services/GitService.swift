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
        try git(["pull", "--ff-only"], at: repo)
    }
}

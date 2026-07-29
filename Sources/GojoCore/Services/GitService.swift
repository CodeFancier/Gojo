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
}

import Foundation
import XCTest
@testable import GojoCore

enum TestSupport {
    static func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gojo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 在指定目录建立一个可克隆的本地源 git 仓库，返回其 file:// URL 字符串。
    @discardableResult
    static func makeLocalGitRepo(named name: String, in parent: URL) throws -> URL {
        let repo = parent.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        let shell = ShellRunner()
        _ = try shell.run("git", ["init", "-q", "-b", "main"], cwd: repo)
        _ = try shell.run("git", ["config", "user.email", "t@t.io"], cwd: repo)
        _ = try shell.run("git", ["config", "user.name", "t"], cwd: repo)
        try "hello".write(to: repo.appendingPathComponent("README.md"),
                          atomically: true, encoding: .utf8)
        _ = try shell.run("git", ["add", "."], cwd: repo)
        _ = try shell.run("git", ["commit", "-q", "-m", "init"], cwd: repo)
        return repo
    }
}

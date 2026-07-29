import XCTest
@testable import GojoCore

final class GitServiceTests: XCTestCase {
    func testCloneLocalRepo() throws {
        let sandbox = try TestSupport.makeTempDir()
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        let dest = sandbox.appendingPathComponent("cloned")

        try GitService().clone(url: source.path, into: dest)

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dest.appendingPathComponent("README.md").path))
    }

    func testCloneInvalidURLThrows() throws {
        let sandbox = try TestSupport.makeTempDir()
        let dest = sandbox.appendingPathComponent("nope")
        XCTAssertThrowsError(
            try GitService().clone(url: "/definitely/not/a/repo", into: dest))
    }

    func testBranchOperations() throws {
        let sandbox = try TestSupport.makeTempDir()
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        // 在源仓库建第二个分支
        _ = try ShellRunner().run("git", ["branch", "feature"], cwd: source)

        let dest = sandbox.appendingPathComponent("cloned")
        let git = GitService()
        try git.clone(url: source.path, into: dest)

        XCTAssertEqual(try git.currentBranch(at: dest), "main")

        let branches = try git.listBranches(at: dest)
        // Verify no duplicates: deduplicated length equals original length
        let deduped = Array(Set(branches))
        XCTAssertEqual(branches.count, deduped.count, "Branch list should have no duplicates")
        XCTAssertTrue(branches.contains("main"), "Should contain 'main' branch")
        XCTAssertTrue(branches.contains("feature"), "Should contain 'feature' branch")

        try git.checkout(branch: "feature", at: dest)
        XCTAssertEqual(try git.currentBranch(at: dest), "feature")

        XCTAssertNoThrow(try git.pull(at: dest))
    }

    func testUncommittedChangesDetected() throws {
        let sandbox = try TestSupport.makeTempDir()
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        let dest = sandbox.appendingPathComponent("clone")
        let git = GitService()
        try git.clone(url: source.path, into: dest)

        XCTAssertFalse(try git.hasUncommittedChanges(at: dest))
        try "dirty".write(to: dest.appendingPathComponent("new.txt"),
                          atomically: true, encoding: .utf8)
        XCTAssertTrue(try git.hasUncommittedChanges(at: dest))
    }

    func testUnpushedCommitsDetected() throws {
        let sandbox = try TestSupport.makeTempDir()
        let source = try TestSupport.makeLocalGitRepo(named: "src", in: sandbox)
        let dest = sandbox.appendingPathComponent("clone")
        let git = GitService()
        try git.clone(url: source.path, into: dest)

        // 刚 clone，HEAD == origin/main，无未推送
        XCTAssertFalse(try git.hasUnpushedCommits(at: dest))

        // 本地新提交 → 未推送
        let shell = ShellRunner()
        _ = try shell.run("git", ["config", "user.email", "t@t.io"], cwd: dest)
        _ = try shell.run("git", ["config", "user.name", "t"], cwd: dest)
        try "x".write(to: dest.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        _ = try shell.run("git", ["add", "."], cwd: dest)
        _ = try shell.run("git", ["commit", "-q", "-m", "local"], cwd: dest)
        XCTAssertTrue(try git.hasUnpushedCommits(at: dest))
    }

    func testNoUpstreamTreatedAsUnpushed() throws {
        let sandbox = try TestSupport.makeTempDir()
        // makeLocalGitRepo 建的是本地初始化仓库，无上游
        let repo = try TestSupport.makeLocalGitRepo(named: "solo", in: sandbox)
        XCTAssertTrue(try GitService().hasUnpushedCommits(at: repo))
    }
}

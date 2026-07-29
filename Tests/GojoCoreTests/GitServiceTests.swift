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
        XCTAssertTrue(try git.listBranches(at: dest).contains("feature"))

        try git.checkout(branch: "feature", at: dest)
        XCTAssertEqual(try git.currentBranch(at: dest), "feature")

        XCTAssertNoThrow(try git.pull(at: dest))
    }
}

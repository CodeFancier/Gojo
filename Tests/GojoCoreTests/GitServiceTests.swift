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
}

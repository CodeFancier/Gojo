import XCTest
@testable import GojoCore

final class ShellRunnerTests: XCTestCase {
    func testEchoStdout() throws {
        let result = try ShellRunner().run("echo", ["hello"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testNonzeroExit() throws {
        // `false` 总是返回非零
        let result = try ShellRunner().run("false", [])
        XCTAssertNotEqual(result.exitCode, 0)
    }
}

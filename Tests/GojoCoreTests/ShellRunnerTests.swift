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

    func testLargeStderrDoesNotDeadlock() throws {
        // 回归旧实现的顺序读取死锁：stderr 喂 200KB（远超管道缓冲区 64KB）且
        // stdout 无输出——正是 git clone 的输出形态。旧实现先同步读 stdout 到
        // EOF，会永远等不到（子进程已阻塞在写 stderr 上），本用例会挂死超时。
        let result = try ShellRunner().run(
            "sh", ["-c", "head -c 200000 /dev/zero | tr '\\0' 'x' >&2"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stderr.count, 200000)
        XCTAssertEqual(result.stdout, "")
    }
}

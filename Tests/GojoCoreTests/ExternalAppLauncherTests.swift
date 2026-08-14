import XCTest
@testable import GojoCore

final class ExternalAppLauncherTests: XCTestCase {
    let path = URL(fileURLWithPath: "/tmp/space")

    func testFinderSpec() {
        let spec = ExternalAppLauncher().launchSpec(for: .finder, path: path)
        XCTAssertEqual(spec, LaunchSpec(executable: "open", arguments: ["/tmp/space"]))
    }

    func testTerminalSpecs() {
        let l = ExternalAppLauncher()
        XCTAssertEqual(l.launchSpec(for: .terminal(.terminal), path: path).arguments,
                       ["-b", "com.apple.Terminal", "/tmp/space"])
        XCTAssertEqual(l.launchSpec(for: .terminal(.iterm2), path: path).arguments,
                       ["-b", "com.googlecode.iterm2", "/tmp/space"])
        XCTAssertEqual(l.launchSpec(for: .terminal(.warp), path: path).arguments,
                       ["-b", "dev.warp.Warp-Stable", "/tmp/space"])
    }

    /// 首选 bundle id 未装（非零退出码）时应沿候选链回退到 Warp Preview。
    func testWarpPreviewFallback() throws {
        let stub = ShellStub(failingPrefixes: ["-b dev.warp.Warp-Stable"])
        let launcher = ExternalAppLauncher(run: stub.call)
        XCTAssertNoThrow(try launcher.launch(.terminal(.warp), path: path))
        XCTAssertEqual(stub.invocations.map { $0.joined(separator: " ") },
                       ["-b dev.warp.Warp-Stable /tmp/space",
                        "-b dev.warp.Warp-Preview /tmp/space"])
    }

    /// 全部候选未命中时抛 TerminalLaunchError，且每个候选都试过。
    func testTerminalNotFound() {
        let stub = ShellStub(failAll: true)
        let launcher = ExternalAppLauncher(run: stub.call)
        XCTAssertThrowsError(try launcher.launch(.terminal(.terminal), path: path)) { error in
            XCTAssertTrue(error is TerminalLaunchError)
        }
        // terminal：1 个 bundle id + 1 个应用名，共 2 次尝试
        XCTAssertEqual(stub.invocations.count, 2)
    }

    func testResumeScriptClaude() {
        let script = ExternalAppLauncher().resumeScript(
            .claude, sessionId: "sid-1", cwd: URL(fileURLWithPath: "/tmp/space"))
        XCTAssertTrue(script.contains("cd '/tmp/space'"))
        XCTAssertTrue(script.contains("claude --resume 'sid-1'"))
    }

    func testResumeScriptCodex() {
        let script = ExternalAppLauncher().resumeScript(
            .codex, sessionId: "cs-2", cwd: URL(fileURLWithPath: "/tmp/space"))
        XCTAssertTrue(script.contains("codex resume 'cs-2'"))
    }
}

/// 测试用 shell 桩：invocations 记录每次调用参数；
/// failAll 全部失败，否则参数前缀命中 failingPrefixes 时返回非零退出码（模拟未安装）。
private final class ShellStub {
    var invocations: [[String]] = []
    private let failAll: Bool
    private let failingPrefixes: [[String]]

    init(failAll: Bool = false, failingPrefixes: [[String]] = []) {
        self.failAll = failAll
        self.failingPrefixes = failingPrefixes
    }

    func call(_ tool: String, _ args: [String]) throws -> ShellResult {
        invocations.append(args)
        let failed = failAll || failingPrefixes.contains { prefix in
            Array(args.prefix(prefix.count)) == prefix
        }
        return ShellResult(stdout: "", stderr: failed ? "not found" : "",
                           exitCode: failed ? 1 : 0)
    }
}

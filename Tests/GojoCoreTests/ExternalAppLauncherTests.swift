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
                       ["-a", "Terminal", "/tmp/space"])
        XCTAssertEqual(l.launchSpec(for: .terminal(.iterm2), path: path).arguments,
                       ["-a", "iTerm", "/tmp/space"])
        XCTAssertEqual(l.launchSpec(for: .terminal(.warp), path: path).arguments,
                       ["-a", "Warp", "/tmp/space"])
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

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
}

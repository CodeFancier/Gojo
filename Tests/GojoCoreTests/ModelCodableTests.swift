import XCTest
@testable import GojoCore

final class ModelCodableTests: XCTestCase {
    func testProjectManifestRoundTrip() throws {
        let manifest = ProjectManifest(
            name: "订单服务",
            repos: [GitRepoBinding(url: "git@example.com:order-api.git",
                                   subdirectory: "order-api", branch: "main")],
            symlinks: [SymlinkBinding(publicRepoName: "shared-lib", linkPath: "shared")]
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(ProjectManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
    }

    func testCentralIndexDefaults() {
        let index = CentralIndex()
        XCTAssertNil(index.publicSpacePath)
        XCTAssertEqual(index.terminalPreference, .terminal)
    }
}

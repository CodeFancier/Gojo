import XCTest
@testable import GojoCore

final class ConfigStoreTests: XCTestCase {
    func testIndexRoundTrip() throws {
        let base = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: base)
        var index = store.loadIndex()          // 缺省文件 → 空索引
        XCTAssertNil(index.publicSpacePath)

        index.publicSpacePath = "/tmp/public"
        index.codingSpacePaths = ["/tmp/ws1"]
        index.terminalPreference = .iterm2
        try store.saveIndex(index)

        let reloaded = ConfigStore(baseDirectory: base).loadIndex()
        XCTAssertEqual(reloaded, index)
    }

    func testWorkspaceManifestRoundTrip() throws {
        let ws = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: try TestSupport.makeTempDir())
        XCTAssertNil(try store.loadWorkspace(at: ws))   // 尚不存在

        let manifest = WorkspaceManifest(name: "电商中台", projectDirectories: ["订单"])
        try store.saveWorkspace(manifest, at: ws)
        XCTAssertEqual(try store.loadWorkspace(at: ws), manifest)
    }

    func testProjectManifestRoundTrip() throws {
        let proj = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: try TestSupport.makeTempDir())
        let manifest = ProjectManifest(name: "订单服务")
        try store.saveProject(manifest, at: proj)
        XCTAssertEqual(try store.loadProject(at: proj), manifest)
    }
}

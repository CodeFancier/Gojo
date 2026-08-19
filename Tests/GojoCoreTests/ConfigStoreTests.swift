import XCTest
@testable import GojoCore

final class ConfigStoreTests: XCTestCase {
    func testIndexRoundTrip() throws {
        let base = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: base)
        var index = store.loadIndex()
        XCTAssertNil(index.publicSpacePath)

        index.publicSpacePath = "/tmp/public"
        index.codingSpaceRootPath = "/tmp/root"
        index.codingSpacePaths = ["/tmp/ws1"]
        index.terminalPreference = .iterm2
        try store.saveIndex(index)

        XCTAssertEqual(ConfigStore(baseDirectory: base).loadIndex(), index)
    }

    /// 磁盘上真实旧版 index.json（无 codingSpaceRootPath key）加载后新字段为 nil，旧字段完好。
    func testLegacyIndexOnDiskLoads() throws {
        let base = try TestSupport.makeTempDir()
        try """
        {
          "codingSpacePaths" : [
            "/tmp/ws1"
          ],
          "publicSpacePath" : "/tmp/public",
          "terminalPreference" : "terminal"
        }
        """.write(to: base.appendingPathComponent("index.json"),
                  atomically: true, encoding: .utf8)

        let index = ConfigStore(baseDirectory: base).loadIndex()

        XCTAssertEqual(index.publicSpacePath, "/tmp/public")
        XCTAssertEqual(index.codingSpacePaths, ["/tmp/ws1"])
        XCTAssertNil(index.codingSpaceRootPath)
    }

    func testPublicSpaceManifestRoundTrip() throws {
        let space = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: try TestSupport.makeTempDir())
        XCTAssertNil(try store.loadPublicSpace(at: space))

        let manifest = PublicSpaceManifest(projects: [
            PublicProject(name: "lib", url: "git@x:lib.git", cloned: false)
        ])
        try store.savePublicSpace(manifest, at: space)
        XCTAssertEqual(try store.loadPublicSpace(at: space), manifest)
    }

    func testWorkspaceManifestRoundTrip() throws {
        let ws = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: try TestSupport.makeTempDir())
        XCTAssertNil(try store.loadWorkspace(at: ws))

        let manifest = WorkspaceManifest(name: "电商中台", members: [
            WorkspaceMember(folderName: "lib", publicProjectId: UUID(), mode: .symlink)
        ])
        try store.saveWorkspace(manifest, at: ws)
        XCTAssertEqual(try store.loadWorkspace(at: ws), manifest)
    }
}

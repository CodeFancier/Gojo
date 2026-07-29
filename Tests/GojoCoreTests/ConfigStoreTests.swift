import XCTest
@testable import GojoCore

final class ConfigStoreTests: XCTestCase {
    func testIndexRoundTrip() throws {
        let base = try TestSupport.makeTempDir()
        let store = ConfigStore(baseDirectory: base)
        var index = store.loadIndex()
        XCTAssertNil(index.publicSpacePath)

        index.publicSpacePath = "/tmp/public"
        index.codingSpacePaths = ["/tmp/ws1"]
        index.terminalPreference = .iterm2
        try store.saveIndex(index)

        XCTAssertEqual(ConfigStore(baseDirectory: base).loadIndex(), index)
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

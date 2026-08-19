import XCTest
@testable import GojoCore

final class ModelCodableTests: XCTestCase {
    func testPublicSpaceManifestRoundTrip() throws {
        let manifest = PublicSpaceManifest(projects: [
            PublicProject(name: "shared-lib", url: "git@example.com:shared-lib.git", cloned: false),
            PublicProject(name: "payment-core", url: "git@example.com:payment.git", cloned: true,
                          relativePath: "suite/payment-core"),
        ])
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(PublicSpaceManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
    }

    func testPublicProjectDecodesManifestWithoutRelativePath() throws {
        let id = UUID()
        let data = Data("""
        {"id":"\(id.uuidString)","name":"legacy","url":"git@example.com:legacy.git","cloned":true}
        """.utf8)

        let project = try JSONDecoder().decode(PublicProject.self, from: data)

        XCTAssertNil(project.relativePath)
        XCTAssertEqual(project.localRelativePath, "legacy")
    }

    func testWorkspaceManifestRoundTrip() throws {
        let pid = UUID()
        let manifest = WorkspaceManifest(name: "电商中台", members: [
            WorkspaceMember(folderName: "shared-lib", publicProjectId: pid, mode: .symlink),
            WorkspaceMember(folderName: "payment-core", publicProjectId: UUID(), mode: .git),
        ])
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(WorkspaceManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
    }

    func testCentralIndexDefaults() {
        let index = CentralIndex()
        XCTAssertNil(index.publicSpacePath)
        XCTAssertNil(index.codingSpaceRootPath)
        XCTAssertEqual(index.terminalPreference, .terminal)
    }

    /// 旧版 index.json 没有 codingSpaceRootPath key，应解码为 nil 而不是失败。
    func testCentralIndexDecodesLegacyJSONWithoutCodingSpaceRoot() throws {
        let data = Data("""
        {"publicSpacePath":"/tmp/public","codingSpacePaths":["/tmp/ws1"],"terminalPreference":"warp"}
        """.utf8)

        let index = try JSONDecoder().decode(CentralIndex.self, from: data)

        XCTAssertEqual(index.publicSpacePath, "/tmp/public")
        XCTAssertEqual(index.codingSpacePaths, ["/tmp/ws1"])
        XCTAssertEqual(index.terminalPreference, .warp)
        XCTAssertNil(index.codingSpaceRootPath)
    }

    /// 终端枚举：新增 otty 后 rawValue 既有约定不变，旧值仍可解码。
    func testTerminalAppCases() {
        XCTAssertEqual(TerminalApp.allCases, [.terminal, .iterm2, .warp, .otty])
        XCTAssertEqual(TerminalApp(rawValue: "otty"), .otty)
        XCTAssertEqual(TerminalApp(rawValue: "warp"), .warp)
        XCTAssertEqual(TerminalApp(rawValue: "terminal"), .terminal)
    }
}

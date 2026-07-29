import XCTest
@testable import GojoCore

final class ModelCodableTests: XCTestCase {
    func testPublicSpaceManifestRoundTrip() throws {
        let manifest = PublicSpaceManifest(projects: [
            PublicProject(name: "shared-lib", url: "git@example.com:shared-lib.git", cloned: false),
            PublicProject(name: "payment-core", url: "git@example.com:payment.git", cloned: true),
        ])
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(PublicSpaceManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
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
        XCTAssertEqual(index.terminalPreference, .terminal)
    }
}

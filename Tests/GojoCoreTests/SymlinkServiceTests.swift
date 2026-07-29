import XCTest
@testable import GojoCore

final class SymlinkServiceTests: XCTestCase {
    func testCreateAndResolve() throws {
        let sandbox = try TestSupport.makeTempDir()
        let target = sandbox.appendingPathComponent("realLib")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let link = sandbox.appendingPathComponent("linkToLib")

        let svc = SymlinkService()
        try svc.createSymlink(at: link, pointingTo: target)

        XCTAssertFalse(svc.isBroken(link))
        let resolved = try FileManager.default.destinationOfSymbolicLink(atPath: link.path)
        XCTAssertEqual(resolved, target.path)
    }

    func testBrokenLinkDetected() throws {
        let sandbox = try TestSupport.makeTempDir()
        let missing = sandbox.appendingPathComponent("gone")
        let link = sandbox.appendingPathComponent("dangling")
        try SymlinkService().createSymlink(at: link, pointingTo: missing)
        XCTAssertTrue(SymlinkService().isBroken(link))
    }
}

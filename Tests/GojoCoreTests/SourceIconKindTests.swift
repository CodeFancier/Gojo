import XCTest
@testable import GojoCore

final class SourceIconKindTests: XCTestCase {
    func testFromMemberFormCoversThreeForms() {
        XCTAssertEqual(SourceIconKind(.standalone), .standalone)
        XCTAssertEqual(SourceIconKind(.publicGit(UUID())), .publicGit)
        XCTAssertEqual(SourceIconKind(.publicSymlink(UUID())), .publicSymlink)
    }

    func testBaseSymbol() {
        XCTAssertEqual(SourceIconKind.standalone.baseSymbol, "shippingbox")
        XCTAssertEqual(SourceIconKind.publicGit.baseSymbol, "shippingbox")
        XCTAssertEqual(SourceIconKind.publicSymlink.baseSymbol, "shippingbox")
        XCTAssertEqual(SourceIconKind.unjoinedPublic.baseSymbol, "globe")
    }

    func testBadge() {
        XCTAssertNil(SourceIconKind.standalone.badgeSymbol)
        XCTAssertEqual(SourceIconKind.publicGit.badgeSymbol, "arrow.triangle.branch")
        XCTAssertEqual(SourceIconKind.publicGit.badgeColorName, "coreBlue")
        XCTAssertEqual(SourceIconKind.publicSymlink.badgeSymbol, "link")
        XCTAssertEqual(SourceIconKind.publicSymlink.badgeColorName, "lightBlue")
        XCTAssertNil(SourceIconKind.unjoinedPublic.badgeSymbol)
    }
}

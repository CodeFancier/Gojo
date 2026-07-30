import XCTest
@testable import GojoCore

final class RouteTests: XCTestCase {
    let space = URL(fileURLWithPath: "/tmp/电商中台")

    func testBackFromDomainGoesToShelf() {
        XCTAssertEqual(Route.publicSpace.back(), .shelf)
        XCTAssertEqual(Route.codingSpace(space).back(), .shelf)
    }

    func testBackFromShelfStaysShelf() {
        XCTAssertEqual(Route.shelf.back(), .shelf)
    }

    func testBeginDroppingOnlyFromCodingSpace() {
        XCTAssertEqual(Route.codingSpace(space).beginDropping(folder: "a"),
                       .shelfDropping(source: space, folder: "a"))
        XCTAssertNil(Route.shelf.beginDropping(folder: "a"))
        XCTAssertNil(Route.publicSpace.beginDropping(folder: "a"))
    }

    func testBackFromDroppingReturnsToSource() {
        XCTAssertEqual(Route.shelfDropping(source: space, folder: "a").back(),
                       .codingSpace(space))
    }

    func testDomainFolder() {
        XCTAssertEqual(Route.codingSpace(space).domainFolder, space)
        XCTAssertNil(Route.shelf.domainFolder)
        XCTAssertNil(Route.publicSpace.domainFolder)
        XCTAssertNil(Route.shelfDropping(source: space, folder: "a").domainFolder)
    }

    func testEnteringFromShelf() {
        XCTAssertEqual(Route.shelf.entering(.codingSpace(space)), .codingSpace(space))
        XCTAssertEqual(Route.shelf.entering(.publicSpace), .publicSpace)
    }
}

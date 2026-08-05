import XCTest
@testable import GojoCore

final class DragPayloadTests: XCTestCase {
    func testMemberRoundTrip() {
        let space = URL(fileURLWithPath: "/tmp/电商中台")
        let s = DragPayload.member(space: space, folder: "order-api")
        let parsed = DragPayload.parseMember(s)
        XCTAssertEqual(parsed?.space, space)
        XCTAssertEqual(parsed?.folder, "order-api")
    }

    func testPublicProjectNotParsedAsMember() {
        let s = DragPayload.publicProject(UUID())
        XCTAssertNil(DragPayload.parseMember(s))
    }

    func testMemberNotParsedAsPublicProject() {
        let s = DragPayload.member(space: URL(fileURLWithPath: "/tmp/x"), folder: "a")
        XCTAssertNil(DragPayload.parsePublicProject(s))
    }

    func testPublicProjectRoundTrip() {
        let id = UUID()
        XCTAssertEqual(DragPayload.parsePublicProject(DragPayload.publicProject(id)), id)
    }

    func testCodingSpaceRoundTrip() {
        let space = URL(fileURLWithPath: "/tmp/编码空间")
        XCTAssertEqual(DragPayload.parseCodingSpace(DragPayload.codingSpace(space)), space)
    }
}

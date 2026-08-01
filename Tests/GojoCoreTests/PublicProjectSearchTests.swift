import XCTest
@testable import GojoCore

final class PublicProjectSearchTests: XCTestCase {
    private let projects = [
        PublicProject(name: "SharedUI", url: "https://git.example.com/design/shared-ui.git"),
        PublicProject(name: "API Kit", url: "ssh://git.example.com/platform/api-kit.git"),
        PublicProject(name: "Docs", url: "https://code.example.com/handbook.git"),
    ]

    func testEmptyAndWhitespaceQueriesPreserveAllProjectsInOrder() {
        XCTAssertEqual(PublicProjectSearch.filter(projects, query: ""), projects)
        XCTAssertEqual(PublicProjectSearch.filter(projects, query: "   "), projects)
    }

    func testNameMatchIsCaseInsensitiveAndTrimmed() {
        XCTAssertEqual(
            PublicProjectSearch.filter(projects, query: "  SHAREDui ").map(\.name),
            ["SharedUI"]
        )
    }

    func testURLMatchIsCaseInsensitive() {
        XCTAssertEqual(
            PublicProjectSearch.filter(projects, query: "PLATFORM/API-KIT").map(\.name),
            ["API Kit"]
        )
    }

    func testNoMatchReturnsEmptyArray() {
        XCTAssertTrue(PublicProjectSearch.filter(projects, query: "missing").isEmpty)
    }
}

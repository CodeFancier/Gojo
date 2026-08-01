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

    func testUserFacingMatchingIgnoresDiacriticsInNamesAndURLs() {
        let localizedProjects = [
            PublicProject(name: "Café Tools", url: "https://git.example.com/tools.git"),
            PublicProject(name: "Profile Kit", url: "https://git.example.com/résumé-kit.git"),
        ]

        XCTAssertEqual(
            PublicProjectSearch.filter(localizedProjects, query: "cafe").map(\.name),
            ["Café Tools"]
        )
        XCTAssertEqual(
            PublicProjectSearch.filter(localizedProjects, query: "resume").map(\.name),
            ["Profile Kit"]
        )
    }

    func testNoMatchReturnsEmptyArray() {
        XCTAssertTrue(PublicProjectSearch.filter(projects, query: "missing").isEmpty)
    }
}

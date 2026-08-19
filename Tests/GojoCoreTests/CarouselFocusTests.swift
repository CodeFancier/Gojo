import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import GojoCore

final class CarouselFocusTests: XCTestCase {
    func testEmptyReturnsNil() {
        XCTAssertNil(CarouselFocus.nearestIndex(cardCentersX: [], viewportCenterX: 100))
    }

    func testSingleCard() {
        XCTAssertEqual(CarouselFocus.nearestIndex(cardCentersX: [50], viewportCenterX: 999), 0)
    }

    func testPicksNearest() {
        let centers: [CGFloat] = [0, 100, 200, 300]
        XCTAssertEqual(CarouselFocus.nearestIndex(cardCentersX: centers, viewportCenterX: 170), 2)
        XCTAssertEqual(CarouselFocus.nearestIndex(cardCentersX: centers, viewportCenterX: 40), 0)
        XCTAssertEqual(CarouselFocus.nearestIndex(cardCentersX: centers, viewportCenterX: 290), 3)
    }

    func testClamp() {
        XCTAssertEqual(CarouselFocus.clampedIndex(-1, count: 3), 0)
        XCTAssertEqual(CarouselFocus.clampedIndex(5, count: 3), 2)
        XCTAssertEqual(CarouselFocus.clampedIndex(1, count: 3), 1)
        XCTAssertEqual(CarouselFocus.clampedIndex(0, count: 0), 0)
    }
}

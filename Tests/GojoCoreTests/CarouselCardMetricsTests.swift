#if canImport(CoreGraphics)
import CoreGraphics
#endif
import XCTest
@testable import GojoCore

final class CarouselCardMetricsTests: XCTestCase {
    func testMinimumViewportClampsFocusedCardAndCentersIt() {
        let metrics = CarouselCardMetrics.calculate(viewportWidth: 400, availableHeight: 180)
        XCTAssertEqual(metrics.focusedSize.width, 240, accuracy: 0.001)
        XCTAssertEqual(metrics.focusedSize.height, 180, accuracy: 0.001)
        XCTAssertEqual(metrics.horizontalInset, 80, accuracy: 0.001)
    }

    func testNormalViewportScalesFluidly() {
        let metrics = CarouselCardMetrics.calculate(viewportWidth: 800, availableHeight: 250)
        XCTAssertEqual(metrics.focusedSize.width, 288, accuracy: 0.001)
        XCTAssertEqual(metrics.focusedSize.height, 206, accuracy: 0.001)
        XCTAssertEqual(metrics.sideSize.width, 184.32, accuracy: 0.001)
        XCTAssertEqual(metrics.sideSize.height, 156.56, accuracy: 0.001)
    }

    func testWideViewportClampsMaximums() {
        let metrics = CarouselCardMetrics.calculate(viewportWidth: 2_000, availableHeight: 500)
        XCTAssertEqual(metrics.focusedSize.width, 360, accuracy: 0.001)
        XCTAssertEqual(metrics.focusedSize.height, 250, accuracy: 0.001)
        XCTAssertEqual(metrics.horizontalInset, 820, accuracy: 0.001)
        XCTAssertEqual(metrics.spacing, 22, accuracy: 0.001)
    }

    func testSideCardMinimumsRemainReadable() {
        let metrics = CarouselCardMetrics.calculate(viewportWidth: 400, availableHeight: 180)
        XCTAssertEqual(metrics.sideSize.width, 153.6, accuracy: 0.001)
        XCTAssertEqual(metrics.sideSize.height, 140, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(metrics.horizontalInset, 0)
    }
}

import XCTest
@testable import GojoCore

final class CarouselKeyboardNavigationTests: XCTestCase {
    func testLeftArrowMovesBackward() {
        XCTAssertEqual(CarouselKeyboardNavigation.delta(forKeyCode: 123), -1)
    }

    func testRightArrowMovesForward() {
        XCTAssertEqual(CarouselKeyboardNavigation.delta(forKeyCode: 124), 1)
    }

    func testOtherKeysPassThrough() {
        XCTAssertNil(CarouselKeyboardNavigation.delta(forKeyCode: 36))
    }
}

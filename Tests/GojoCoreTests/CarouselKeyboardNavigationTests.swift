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

    func testArrowHandlingRequiresActiveNonTextReceiverWindow() {
        XCTAssertTrue(
            CarouselKeyboardNavigation.shouldHandleArrowKey(
                forKeyCode: 124,
                isEventInReceiverWindow: true,
                isReceiverWindowKey: true,
                isApplicationActive: true,
                hasAttachedSheet: false,
                hasModalWindow: false,
                isTextEditing: false
            )
        )

        XCTAssertFalse(
            CarouselKeyboardNavigation.shouldHandleArrowKey(
                forKeyCode: 124,
                isEventInReceiverWindow: true,
                isReceiverWindowKey: true,
                isApplicationActive: true,
                hasAttachedSheet: false,
                hasModalWindow: false,
                isTextEditing: true
            )
        )
        XCTAssertFalse(
            CarouselKeyboardNavigation.shouldHandleArrowKey(
                forKeyCode: 124,
                isEventInReceiverWindow: true,
                isReceiverWindowKey: true,
                isApplicationActive: true,
                hasAttachedSheet: true,
                hasModalWindow: false,
                isTextEditing: false
            )
        )
        XCTAssertFalse(
            CarouselKeyboardNavigation.shouldHandleArrowKey(
                forKeyCode: 36,
                isEventInReceiverWindow: true,
                isReceiverWindowKey: true,
                isApplicationActive: true,
                hasAttachedSheet: false,
                hasModalWindow: false,
                isTextEditing: false
            )
        )
    }

    func testArrowHandlingPassesThroughOutsideEligibleWindowContext() {
        XCTAssertFalse(
            CarouselKeyboardNavigation.shouldHandleArrowKey(
                forKeyCode: 123,
                isEventInReceiverWindow: false,
                isReceiverWindowKey: true,
                isApplicationActive: true,
                hasAttachedSheet: false,
                hasModalWindow: false,
                isTextEditing: false
            )
        )
        XCTAssertFalse(
            CarouselKeyboardNavigation.shouldHandleArrowKey(
                forKeyCode: 123,
                isEventInReceiverWindow: true,
                isReceiverWindowKey: false,
                isApplicationActive: true,
                hasAttachedSheet: false,
                hasModalWindow: false,
                isTextEditing: false
            )
        )
        XCTAssertFalse(
            CarouselKeyboardNavigation.shouldHandleArrowKey(
                forKeyCode: 123,
                isEventInReceiverWindow: true,
                isReceiverWindowKey: true,
                isApplicationActive: false,
                hasAttachedSheet: false,
                hasModalWindow: false,
                isTextEditing: false
            )
        )
        XCTAssertFalse(
            CarouselKeyboardNavigation.shouldHandleArrowKey(
                forKeyCode: 123,
                isEventInReceiverWindow: true,
                isReceiverWindowKey: true,
                isApplicationActive: true,
                hasAttachedSheet: false,
                hasModalWindow: true,
                isTextEditing: false
            )
        )
    }
}

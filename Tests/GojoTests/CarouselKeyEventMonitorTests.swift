import AppKit
import XCTest
@testable import Gojo

final class CarouselKeyEventMonitorTests: XCTestCase {
    func testUnmappedKeyPassesThroughWithoutCallback() {
        var moves: [Int] = []
        let monitor = CarouselKeyEventMonitor { moves.append($0) }
        let event = keyEvent(keyCode: 36)

        let result = monitor.handle(event, isAllowed: true)

        XCTAssertTrue(result === event)
        XCTAssertTrue(moves.isEmpty)
    }

    func testAllowedArrowKeysAreConsumedAndForwardTheirDeltas() {
        for (keyCode, expectedDelta) in [(UInt16(123), -1), (UInt16(124), 1)] {
            var moves: [Int] = []
            let monitor = CarouselKeyEventMonitor { moves.append($0) }

            let result = monitor.handle(keyEvent(keyCode: keyCode), isAllowed: true)

            XCTAssertNil(result)
            XCTAssertEqual(moves, [expectedDelta])
        }
    }

    func testGateRejectedArrowPassesThroughWithoutCallback() {
        var moves: [Int] = []
        let monitor = CarouselKeyEventMonitor { moves.append($0) }
        let event = keyEvent(keyCode: 124)

        let result = monitor.handle(event, isAllowed: false)

        XCTAssertTrue(result === event)
        XCTAssertTrue(moves.isEmpty)
    }

    private func keyEvent(keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}

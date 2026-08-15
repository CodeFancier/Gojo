import XCTest
@testable import Gojo

final class HoldToDeleteModelTests: XCTestCase {
    private let trashFrame = CGRect(x: 100, y: 200, width: 32, height: 32)

    private var model: HoldToDeleteModel {
        HoldToDeleteModel(trashFrame: trashFrame)
    }

    func testNilLocationNeverHits() {
        XCTAssertFalse(model.hitsTrash(nil))
    }

    func testPointInsideIconHits() {
        XCTAssertTrue(model.hitsTrash(CGPoint(x: 116, y: 216)))
    }

    func testPointWithinInsetOutsideIconHits() {
        // 图标外、外扩 14pt 缓冲区内（ CGRect 边界半开，取内缩 1pt 的点）。
        let inset = HoldToDeleteModel.hitInset - 1
        XCTAssertTrue(model.hitsTrash(CGPoint(x: 100 - inset, y: 216)))
        XCTAssertTrue(model.hitsTrash(CGPoint(x: 132 + inset, y: 216)))
        XCTAssertTrue(model.hitsTrash(CGPoint(x: 116, y: 232 + inset)))
    }

    func testPointBeyondInsetMisses() {
        let beyond = HoldToDeleteModel.hitInset + 1
        XCTAssertFalse(model.hitsTrash(CGPoint(x: 100 - beyond, y: 216)))
        XCTAssertFalse(model.hitsTrash(CGPoint(x: 132 + beyond, y: 216)))
        XCTAssertFalse(model.hitsTrash(CGPoint(x: 116, y: 232 + beyond)))
    }

    func testDropTargetExpandsSymmetrically() {
        let target = model.dropTarget
        XCTAssertEqual(target.minX, trashFrame.minX - HoldToDeleteModel.hitInset, accuracy: 0.001)
        XCTAssertEqual(target.maxX, trashFrame.maxX + HoldToDeleteModel.hitInset, accuracy: 0.001)
        XCTAssertEqual(target.minY, trashFrame.minY - HoldToDeleteModel.hitInset, accuracy: 0.001)
        XCTAssertEqual(target.maxY, trashFrame.maxY + HoldToDeleteModel.hitInset, accuracy: 0.001)
    }
}

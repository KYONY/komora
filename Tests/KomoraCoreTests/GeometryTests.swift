import XCTest
@testable import KomoraCore

final class GeometryTests: XCTestCase {
    func testPlanOnThisMac() {
        // landscape 2320 pt + portrait 1026 pt, measured (research/probe/ax.swift).
        let p = Geometry.plan(widths: [2320, 1026])
        XCTAssertEqual(p.unit, 449)
        XCTAssertEqual(p.count, 6) // ceil(2320/465)=5, +1 spare
        XCTAssertGreaterThan(CGFloat(p.count) * (p.unit + Geometry.chrome), 2320)
    }
    func testPlanSingleDisplay() {
        let p = Geometry.plan(widths: [1512])
        XCTAssertEqual(p.unit, 692)
        XCTAssertEqual(p.count, 4) // ceil(1512/708)=3, +1 spare
    }
    func testPlanEmpty() { XCTAssertEqual(Geometry.plan(widths: []).count, 8) }
    func testPusherKeysExactInFloat32AndOrdered() {
        for divider in [250.0, 498.7490234375, 1000.25] {
            let keys = (0..<Geometry.maxPushers).map { Keys.pusher($0, divider: divider) }
            for k in keys { XCTAssertEqual(Double(Float(k)), k) }
            XCTAssertEqual(Set(keys.map { Float($0) }).count, Geometry.maxPushers)
            XCTAssertTrue(keys.allSatisfy { $0 > divider && $0 <= divider + 1.0 / 512 })
        }
    }
    func testAdjacentCollapsed() {
        let d = Verify.Frame(minX: 1963, width: 26)
        let ps = [Verify.Frame(minX: 1498, width: 465), .init(minX: 1033, width: 465), .init(minX: 0, width: 465)]
        XCTAssertTrue(Verify.pushersAdjacent(divider: d, pushers: ps))
    }
    func testNotAdjacentWhenIconBetween() {
        let d = Verify.Frame(minX: 1963, width: 26)
        let ps = [Verify.Frame(minX: 1460, width: 465)] // gap of 38 pt = a foreign icon
        XCTAssertFalse(Verify.pushersAdjacent(divider: d, pushers: ps))
    }
    func testAllOverflowed() {
        let d = Verify.Frame(minX: 1963, width: 26)
        XCTAssertTrue(Verify.pushersAdjacent(divider: d, pushers: [.init(minX: 0, width: 465)]))
    }
    func testDividerOverflowedFails() {
        let d = Verify.Frame(minX: 0, width: 26)
        XCTAssertFalse(Verify.pushersAdjacent(divider: d, pushers: [.init(minX: 0, width: 465)]))
    }
    func testLeftmostPusherOffByEightPasses() {
        // Komora.log 17:10:46: divider 1719, pushers 1254, 789, 316 (all 465 wide).
        let d = Verify.Frame(minX: 1719, width: 26)
        let ps = [Verify.Frame(minX: 1254, width: 465), .init(minX: 789, width: 465), .init(minX: 316, width: 465), .init(minX: 0, width: 465)]
        XCTAssertTrue(Verify.pushersAdjacent(divider: d, pushers: ps))
    }
    func testZeroFramePushersFail() {
        let d = Verify.Frame(minX: 1963, width: 26)
        XCTAssertFalse(Verify.pushersAdjacent(divider: d, pushers: [.init(minX: 0, width: 0), .init(minX: 0, width: 0)]))
    }
    func testNoOverflowFails() {
        // Chain is unbroken but nothing overflowed: coverage did not reach the left end.
        let d = Verify.Frame(minX: 1963, width: 26)
        XCTAssertFalse(Verify.pushersAdjacent(divider: d, pushers: [.init(minX: 1498, width: 465)]))
    }
    func testGapInsideChainFails() {
        let d = Verify.Frame(minX: 1963, width: 26)
        let ps = [Verify.Frame(minX: 1498, width: 465), .init(minX: 995, width: 465), .init(minX: 0, width: 465)] // 38 pt icon between pushers
        XCTAssertFalse(Verify.pushersAdjacent(divider: d, pushers: ps))
    }
    func testPlanWideAndNarrowNotClamped() {
        let p = Geometry.plan(widths: [3840, 500])
        XCTAssertGreaterThan(CGFloat(p.count) * (p.unit + Geometry.chrome), 3840)
    }
}

import XCTest

final class ScrollSmootherTests: XCTestCase {
    private func drain(_ smoother: inout ScrollSmoother, frames: Int = 2000) -> (x: Int, y: Int, frames: Int) {
        var x = 0, y = 0, used = 0
        while !smoother.isIdle && used < frames {
            let out = smoother.step(dt: 1.0 / 120, timeConstant: 0.13)
            x += Int(out.x)
            y += Int(out.y)
            used += 1
        }
        return (x, y, used)
    }

    func testTotalDistanceIsPreserved() {
        var smoother = ScrollSmoother()
        smoother.add(dx: 0, dy: -240)
        let total = drain(&smoother)
        XCTAssertEqual(total.y, -240)
        XCTAssertEqual(total.x, 0)
        XCTAssertTrue(smoother.isIdle)
    }

    func testMovementIsSpreadOverManyFrames() {
        var smoother = ScrollSmoother()
        smoother.add(dx: 0, dy: 100)
        let first = smoother.step(dt: 1.0 / 120, timeConstant: 0.13)
        XCTAssertGreaterThan(first.y, 0)
        XCTAssertLessThan(first.y, 20)
        let rest = drain(&smoother)
        XCTAssertGreaterThan(rest.frames, 20)
        XCTAssertEqual(Int(first.y) + rest.y, 100)
    }

    func testReversingDropsPendingDistance() {
        var smoother = ScrollSmoother()
        smoother.add(dx: 0, dy: 500)
        _ = smoother.step(dt: 1.0 / 120, timeConstant: 0.13)
        smoother.add(dx: 0, dy: -50)
        XCTAssertEqual(smoother.remainingY, -50, accuracy: 0.001)
    }

    func testAxesAreIndependent() {
        var smoother = ScrollSmoother()
        smoother.add(dx: 77, dy: -33)
        let total = drain(&smoother)
        XCTAssertEqual(total.x, 77)
        XCTAssertEqual(total.y, -33)
    }

    func testOldSavedSettingsKeepValuesAndGainDefaults() throws {
        // Saved before `wheelMode` existed, with a customised speed.
        let old = #"{"scroll":{"smoothEnabled":true,"speed":5.5},"buttonsEnabled":false}"#
        let settings = try XCTUnwrap(AppSettings.decode(Data(old.utf8)))
        XCTAssertEqual(settings.scroll.speed, 5.5)
        XCTAssertEqual(settings.scroll.wheelMode, .smooth)
        XCTAssertEqual(settings.scroll.linesPerTick, 3)
        XCTAssertFalse(settings.buttonsEnabled)
        XCTAssertEqual(settings.appRules, AppSettings().appRules)
    }

    func testDirectionHelpers() {
        XCTAssertFalse(ScrollDirection.system.needsReversal(systemIsNatural: true))
        XCTAssertTrue(ScrollDirection.traditional.needsReversal(systemIsNatural: true))
        XCTAssertFalse(ScrollDirection.traditional.needsReversal(systemIsNatural: false))
        XCTAssertTrue(ScrollDirection.natural.needsReversal(systemIsNatural: false))
    }
}

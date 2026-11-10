import Foundation

/// Turns discrete wheel ticks into a stream of small per-frame pixel deltas
/// using exponential easing. Whole pixels are emitted; fractions are carried
/// over so the total distance is preserved.
struct ScrollSmoother {
    private(set) var remainingX = 0.0
    private(set) var remainingY = 0.0
    private var fractionX = 0.0
    private var fractionY = 0.0

    var isIdle: Bool {
        abs(remainingX) < 0.5 && abs(remainingY) < 0.5
    }

    /// Queue more distance (in pixels). Reversing direction drops whatever was
    /// still pending on that axis so the change feels immediate.
    mutating func add(dx: Double, dy: Double) {
        if dx != 0 {
            if dx.sign != remainingX.sign { remainingX = 0; fractionX = 0 }
            remainingX += dx
        }
        if dy != 0 {
            if dy.sign != remainingY.sign { remainingY = 0; fractionY = 0 }
            remainingY += dy
        }
    }

    /// Advance by `dt` seconds. `timeConstant` is how long it takes to cover
    /// about 63 % of the pending distance.
    mutating func step(dt: Double, timeConstant: Double) -> (x: Int32, y: Int32) {
        let k = 1 - exp(-dt / max(timeConstant, 0.001))
        let x = Self.advance(&remainingX, &fractionX, k)
        let y = Self.advance(&remainingY, &fractionY, k)
        return (x, y)
    }

    mutating func reset() {
        self = ScrollSmoother()
    }

    private static func advance(_ remaining: inout Double, _ fraction: inout Double, _ k: Double) -> Int32 {
        var emitted = remaining * k
        remaining -= emitted
        if abs(remaining) < 0.5 {
            // Close enough: flush the tail so nothing is lost.
            emitted += remaining
            remaining = 0
            fraction += emitted
            let whole = fraction.rounded()
            fraction = 0
            return Int32(whole)
        }
        fraction += emitted
        let whole = fraction.rounded(.towardZero)
        fraction -= whole
        return Int32(whole)
    }
}

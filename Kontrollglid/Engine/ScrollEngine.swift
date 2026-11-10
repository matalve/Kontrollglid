import AppKit
import CoreGraphics
import QuartzCore

/// Smooths mouse-wheel scrolling and sets the scroll direction separately for
/// mouse wheels and trackpads.
final class ScrollEngine: NSObject {
    private var tap: EventTap?
    private var smoother = ScrollSmoother()
    private var link: CADisplayLink?
    private var fallbackTimer: Timer?
    private var postFlags = CGEventFlags()
    private var timeConstant = 0.13
    private var systemIsNatural = true
    private var systemCheckedAt = Date.distantPast

    private var settings: AppSettings { SettingsStore.shared.settings }

    func start() -> Bool {
        guard tap == nil else { return true }
        tap = EventTap(events: [.scrollWheel]) { [weak self] _, event in
            guard let self else { return event }
            return self.handle(event)
        }
        return tap != nil
    }

    func stop() {
        tap = nil
        pause()
        smoother.reset()
    }

    // MARK: - Incoming events

    private func handle(_ event: CGEvent) -> CGEvent? {
        if Synthetic.isSynthetic(event) { return event }
        let scroll = settings.scroll
        refreshSystemDirection()

        // Trackpads and Magic Mouse already scroll smoothly; only fix direction.
        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 {
            if scroll.trackpadDirection.needsReversal(systemIsNatural: systemIsNatural) { Self.invert(event) }
            return event
        }

        let reverse = scroll.mouseDirection.needsReversal(systemIsNatural: systemIsNatural)
        let held = Modifiers(event.flags)
        let appRule = settings.rule(for: AppState.shared.frontBundleID)
        var mode = appRule?.disableSmoothScroll == true ? WheelMode.system : scroll.wheelMode
        if mode == .smooth, scroll.bypassModifier.isHeld(in: held) { mode = .system }
        switch mode {
        case .system:
            if reverse { Self.invert(event) }
            return event
        case .linear:
            postLinear(event, scroll: scroll, reverse: reverse, held: held)
            return nil
        case .smooth:
            break
        }

        var dy = Self.distance(event, point: .scrollWheelEventPointDeltaAxis1, line: .scrollWheelEventDeltaAxis1, scroll: scroll)
        var dx = Self.distance(event, point: .scrollWheelEventPointDeltaAxis2, line: .scrollWheelEventDeltaAxis2, scroll: scroll)
        if reverse { dy = -dy; dx = -dx }

        var strip = Modifiers()
        if scroll.dashModifier.isHeld(in: held) {
            dy *= scroll.dashMultiplier
            dx *= scroll.dashMultiplier
            strip.insert(scroll.dashModifier.modifiers)
        }
        if scroll.horizontalModifier.isHeld(in: held) {
            // macOS may already have turned Shift+wheel into a horizontal event.
            if dx == 0 { dx = dy; dy = 0 }
            strip.insert(scroll.horizontalModifier.modifiers)
        }

        // The helper modifiers must not reach the app, or it would react to them too.
        postFlags = CGEventFlags(rawValue: event.flags.rawValue & ~Synthetic.flagBits(for: strip))
        timeConstant = scroll.timeConstant
        smoother.add(dx: dx, dy: dy)
        resume()
        return nil
    }

    /// Replace an accelerated wheel event with one that scrolls a fixed number
    /// of lines, so the first notch moves exactly as far as every later one.
    private func postLinear(_ event: CGEvent, scroll: ScrollSettings, reverse: Bool, held: Modifiers) {
        var lines = scroll.linesPerTick
        var strip = Modifiers()
        if scroll.dashModifier.isHeld(in: held) {
            lines *= scroll.dashMultiplier
            strip.insert(scroll.dashModifier.modifiers)
        }
        let amount = Int32(max(1, lines.rounded())) * (reverse ? -1 : 1)
        var y = Self.direction(event, axis: 1) * amount
        var x = Self.direction(event, axis: 2) * amount
        if scroll.horizontalModifier.isHeld(in: held) {
            if x == 0 { x = y; y = 0 }
            strip.insert(scroll.horizontalModifier.modifiers)
        }
        guard x != 0 || y != 0,
              let out = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0) else { return }
        out.flags = CGEventFlags(rawValue: event.flags.rawValue & ~Synthetic.flagBits(for: strip))
        out.setIntegerValueField(.eventSourceUserData, value: Synthetic.marker)
        out.post(tap: .cgSessionEventTap)
    }

    /// -1, 0 or 1 for the direction of a wheel event on one axis. Slow notches
    /// can have a zero line delta, so fall back to the finer-grained fields.
    private static func direction(_ event: CGEvent, axis: Int) -> Int32 {
        let fields: (CGEventField, CGEventField, CGEventField) = axis == 1
            ? (.scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1)
            : (.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2)
        var value = Double(event.getIntegerValueField(fields.0))
        if value == 0 { value = event.getDoubleValueField(fields.1) }
        if value == 0 { value = Double(event.getIntegerValueField(fields.2)) }
        return value > 0 ? 1 : (value < 0 ? -1 : 0)
    }

    private static func distance(_ event: CGEvent, point: CGEventField, line: CGEventField, scroll: ScrollSettings) -> Double {
        var pixels = Double(event.getIntegerValueField(point))
        if pixels == 0 { pixels = Double(event.getIntegerValueField(line)) * 10 }
        guard pixels != 0 else { return 0 }
        return (pixels < 0 ? -1 : 1) * max(abs(pixels), scroll.step) * scroll.speed
    }

    /// Flip both axes of a scroll event in place.
    private static func invert(_ event: CGEvent) {
        let axes: [(CGEventField, CGEventField, CGEventField)] = [
            (.scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1),
            (.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2),
        ]
        for (line, fixed, point) in axes {
            let lineValue = event.getIntegerValueField(line)
            let fixedValue = event.getDoubleValueField(fixed)
            let pointValue = event.getIntegerValueField(point)
            // Order matters: writing the line delta recalculates the other two.
            event.setIntegerValueField(line, value: -lineValue)
            event.setDoubleValueField(fixed, value: -fixedValue)
            event.setIntegerValueField(point, value: -pointValue)
        }
    }

    private func refreshSystemDirection() {
        guard Date().timeIntervalSince(systemCheckedAt) > 5 else { return }
        systemCheckedAt = Date()
        systemIsNatural = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
    }

    // MARK: - Animation

    private func resume() {
        if link == nil, fallbackTimer == nil {
            if let screen = NSScreen.main {
                let link = screen.displayLink(target: self, selector: #selector(displayTick(_:)))
                link.add(to: .main, forMode: .common)
                self.link = link
            } else {
                let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
                    self?.advance(dt: 1.0 / 120)
                }
                RunLoop.main.add(timer, forMode: .common)
                fallbackTimer = timer
            }
        }
        link?.isPaused = false
    }

    private func pause() {
        link?.isPaused = true
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    @objc private func displayTick(_ link: CADisplayLink) {
        advance(dt: min(max(link.targetTimestamp - link.timestamp, 1.0 / 240), 1.0 / 30))
    }

    private func advance(dt: Double) {
        let out = smoother.step(dt: dt, timeConstant: timeConstant)
        if out.x != 0 || out.y != 0 { post(x: out.x, y: out.y) }
        if smoother.isIdle { pause() }
    }

    private func post(x: Int32, y: Int32) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0) else { return }
        event.flags = postFlags
        event.setIntegerValueField(.eventSourceUserData, value: Synthetic.marker)
        event.post(tap: .cgSessionEventTap)
    }
}

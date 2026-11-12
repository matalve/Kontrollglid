import AppKit
import ApplicationServices

/// Moves the focused window to the neighbouring display, like Win+Shift+arrow
/// on Windows. Uses the Accessibility API, which the app already has access to.
enum WindowMover {
    /// True while a full-screen window is on its way to another display.
    private static var busy = false

    static func moveFocusedWindow(toNext: Bool) {
        guard !busy, NSScreen.screens.count > 1,
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let window = focusedWindow(pid: pid),
              let frame = frame(of: window) else { return }
        let areas = displayAreas()
        let current = index(of: frame, in: areas)
        let target = (current + (toNext ? 1 : -1) + areas.count) % areas.count
        guard target != current else { return }

        guard isFullScreen(window) else {
            place(window, frame: frame, from: areas[current], into: areas[target])
            return
        }
        // macOS refuses to move a full-screen window, so take it out of full
        // screen and move it once the animation has finished. It deliberately
        // stays an ordinary window: what is full screen on a small display
        // rarely needs to be on a large one.
        busy = true
        setFullScreen(window, false)
        waitUntilSettled(window, attemptsLeft: 40) { settled in
            defer { busy = false }
            guard settled, let restored = self.frame(of: window) else { return }
            // The window returns to wherever it was before it went full screen.
            let areas = displayAreas()
            guard target < areas.count else { return }
            place(window, frame: restored, from: areas[index(of: restored, in: areas)], into: areas[target])
        }
    }

    /// Poll until the window has left full screen and stopped animating.
    private static func waitUntilSettled(
        _ window: AXUIElement, attemptsLeft: Int, last: CGRect? = nil, done: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let now = frame(of: window)
            if !isFullScreen(window), now != nil, now == last { return done(true) }
            if attemptsLeft == 0 { return done(false) }
            waitUntilSettled(window, attemptsLeft: attemptsLeft - 1, last: now, done: done)
        }
    }

    /// The usable area of every display, left to right, in Accessibility
    /// coordinates: origin at the top left of the primary display, where
    /// AppKit has it at the bottom left.
    private static func displayAreas() -> [CGRect] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }.map { screen in
            let frame = screen.visibleFrame
            return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
        }
    }

    private static func index(of window: CGRect, in areas: [CGRect]) -> Int {
        let centre = CGPoint(x: window.midX, y: window.midY)
        return areas.firstIndex { $0.contains(centre) }
            ?? areas.indices.min { distance(areas[$0], centre) < distance(areas[$1], centre) } ?? 0
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        guard let origin: CGPoint = value(window, kAXPositionAttribute, .cgPoint),
              let size: CGSize = value(window, kAXSizeAttribute, .cgSize) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func place(_ window: AXUIElement, frame: CGRect, from source: CGRect, into target: CGRect) {
        let frame = fit(frame, from: source, into: target)
        // Size, position, size: a window cannot grow past the display it is
        // on, so the first resize may be clipped until it has moved.
        set(window, kAXSizeAttribute, frame.size)
        set(window, kAXPositionAttribute, frame.origin)
        set(window, kAXSizeAttribute, frame.size)
    }

    private static func setFullScreen(_ window: AXUIElement, _ on: Bool) {
        AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, on as CFBoolean)
    }

    /// Keep the window's relative place on the display, shrinking it if the
    /// target display is smaller.
    static func fit(_ window: CGRect, from source: CGRect, into target: CGRect) -> CGRect {
        let width = min(window.width, target.width)
        let height = min(window.height, target.height)
        func place(_ offset: CGFloat, _ free: CGFloat, _ newFree: CGFloat) -> CGFloat {
            free > 0 ? min(max(offset / free, 0), 1) * newFree : newFree / 2
        }
        let x = target.minX + place(window.minX - source.minX, source.width - window.width, target.width - width)
        let y = target.minY + place(window.minY - source.minY, source.height - window.height, target.height - height)
        return CGRect(x: x.rounded(), y: y.rounded(), width: width, height: height)
    }

    private static func distance(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
        hypot(rect.midX - point.x, rect.midY - point.y)
    }

    private static func focusedWindow(pid: pid_t) -> AXUIElement? {
        var ref: CFTypeRef?
        let app = AXUIElementCreateApplication(pid)
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }

    private static func isFullScreen(_ window: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &ref)
        return (ref as? Bool) ?? false
    }

    private static func value<T>(_ element: AXUIElement, _ attribute: String, _ type: AXValueType) -> T? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        let result = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { result.deallocate() }
        return AXValueGetValue(ref as! AXValue, type, result) ? result.pointee : nil
    }

    private static func set(_ element: AXUIElement, _ attribute: String, _ point: CGPoint) {
        var point = point
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(element, attribute as CFString, value)
        }
    }

    private static func set(_ element: AXUIElement, _ attribute: String, _ size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, attribute as CFString, value)
        }
    }
}

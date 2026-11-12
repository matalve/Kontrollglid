import AppKit
import ApplicationServices

/// Moves the focused window to the neighbouring display, like Win+Shift+arrow
/// on Windows. Uses the Accessibility API, which the app already has access to.
enum WindowMover {
    static func moveFocusedWindow(toNext: Bool) {
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        guard screens.count > 1,
              let primaryHeight = NSScreen.screens.first?.frame.height,
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let window = focusedWindow(pid: pid),
              !isFullScreen(window),
              let origin: CGPoint = value(window, kAXPositionAttribute, .cgPoint),
              let size: CGSize = value(window, kAXSizeAttribute, .cgSize) else { return }

        // Accessibility coordinates have their origin at the top left of the
        // primary display; AppKit's are at its bottom left.
        let areas = screens.map { screen -> CGRect in
            let frame = screen.visibleFrame
            return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
        }
        let centre = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let current = areas.firstIndex { $0.contains(centre) }
            ?? areas.indices.min { distance(areas[$0], centre) < distance(areas[$1], centre) } ?? 0
        let target = (current + (toNext ? 1 : -1) + areas.count) % areas.count
        guard target != current else { return }

        let frame = fit(CGRect(origin: origin, size: size), from: areas[current], into: areas[target])
        // Size, position, size: a window cannot grow past the display it is
        // on, so the first resize may be clipped until it has moved.
        set(window, kAXSizeAttribute, frame.size)
        set(window, kAXPositionAttribute, frame.origin)
        set(window, kAXSizeAttribute, frame.size)
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

import AppKit
import SwiftUI

@main
struct KontrollglidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra("Kontrollglid", systemImage: state.enginesRunning ? "computermouse.fill" : "computermouse") {
            if !state.accessibilityGranted {
                Text("Accessibility permission is missing")
            }
            Picker("Mouse wheel", selection: $store.settings.scroll.wheelMode) {
                Text("Smooth scrolling").tag(WheelMode.smooth)
                Text("No acceleration").tag(WheelMode.linear)
                Text("macOS default").tag(WheelMode.system)
            }
            Toggle("Mouse buttons", isOn: $store.settings.buttonsEnabled)
            Toggle("Windows shortcuts", isOn: $store.settings.keyboard.enabled)
            Divider()
            Button("Settings…") { SettingsWindow.shared.show() }
                .keyboardShortcut(",")
            Button("Quit Kontrollglid") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.start()
        // First run: show the window so the permissions can be granted.
        if !AppState.shared.accessibilityGranted {
            SettingsWindow.shared.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.show()
        return false
    }
}

/// The settings window, managed by hand because the app has no Dock icon.
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Kontrollglid"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            self.window = window
        }
        guard let window else { return }
        if !window.isVisible || !window.isOnActiveSpace {
            moveToScreenWithMouse(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // A menu bar app is not always allowed to activate itself, so force the
        // window above whatever is currently in front.
        window.orderFrontRegardless()
    }

    /// Centre the window on the display the user is looking at, not whichever
    /// display happens to own keyboard focus.
    private func moveToScreenWithMouse(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return window.center() }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }
}

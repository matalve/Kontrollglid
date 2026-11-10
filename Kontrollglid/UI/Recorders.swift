import AppKit
import SwiftUI

/// A button that captures the next key combination pressed.
struct ShortcutRecorder: View {
    @Binding var stroke: KeyStroke
    @State private var monitor: Any?

    var body: some View {
        Button(monitor == nil ? KeyNames.describe(stroke) : "Press a combination…") {
            monitor == nil ? start() : stop()
        }
        .frame(minWidth: 130)
        .onDisappear(perform: stop)
    }

    private func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = Modifiers(event.modifierFlags)
            // Plain Esc cancels; anything else becomes the new shortcut.
            if !(event.keyCode == KeyCode.escape && modifiers.isEmpty) {
                stroke = KeyStroke(event.keyCode, modifiers)
            }
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// A button that waits for an extra mouse button to be clicked and reports its number.
struct MouseButtonRecorder: View {
    let title: String
    let onRecord: (Int) -> Void
    @State private var monitor: Any?

    var body: some View {
        Button(monitor == nil ? title : "Click the mouse button… (Esc cancels)") {
            monitor == nil ? start() : stop()
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .keyDown]) { event in
            if event.type == .otherMouseDown { onRecord(event.buttonNumber) }
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

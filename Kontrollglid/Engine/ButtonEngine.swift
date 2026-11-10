import CoreGraphics
import Foundation

/// Turns extra mouse buttons into keyboard shortcuts.
final class ButtonEngine {
    private var tap: EventTap?

    func start() -> Bool {
        guard tap == nil else { return true }
        tap = EventTap(events: [.otherMouseDown, .otherMouseUp]) { [weak self] type, event in
            guard let self else { return event }
            return self.handle(type, event)
        }
        return tap != nil
    }

    func stop() {
        tap = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        if Synthetic.isSynthetic(event) { return event }
        let settings = SettingsStore.shared.settings
        // Let clicks through to our own window so buttons can be (re)recorded.
        guard settings.buttonsEnabled, !AppState.shared.isFrontmost else { return event }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard let binding = settings.buttons.first(where: { $0.button == button }) else { return event }
        Synthetic.post(binding.stroke, keyDown: type == .otherMouseDown)
        return nil
    }
}

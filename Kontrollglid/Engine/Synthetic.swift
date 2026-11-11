import AppKit
import CoreGraphics

extension Modifiers {
    init(_ flags: CGEventFlags) {
        self = []
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskCommand) { insert(.command) }
    }

    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }
}

/// Helpers for events Kontrollglid creates or rewrites itself.
enum Synthetic {
    /// Stamped on every event we post so our own taps ignore them ("KGLD").
    static let marker: Int64 = 0x4B47_4C44

    /// Device-independent modifier bits plus the left/right device bits.
    private static let allModifierBits: UInt64 =
        CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue |
        CGEventFlags.maskShift.rawValue | CGEventFlags.maskCommand.rawValue |
        0x1 | 0x2 | 0x4 | 0x8 | 0x10 | 0x20 | 0x40 | 0x2000

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }

    /// Flag bits for a set of modifiers, as if the left-hand keys were held.
    static func flagBits(for modifiers: Modifiers) -> UInt64 {
        var raw: UInt64 = 0
        if modifiers.contains(.control) { raw |= CGEventFlags.maskControl.rawValue | 0x1 }
        if modifiers.contains(.shift) { raw |= CGEventFlags.maskShift.rawValue | 0x2 }
        if modifiers.contains(.command) { raw |= CGEventFlags.maskCommand.rawValue | 0x8 }
        if modifiers.contains(.option) { raw |= CGEventFlags.maskAlternate.rawValue | 0x20 }
        return raw
    }

    private static func extraBits(for keyCode: UInt16) -> UInt64 {
        // Real arrow key events always carry both flags, other function keys one.
        if KeyCode.arrows.contains(keyCode) { return keyTypeBits }
        return KeyCode.functionKeys.contains(keyCode) ? CGEventFlags.maskSecondaryFn.rawValue : 0
    }

    private static let keyTypeBits = CGEventFlags.maskNumericPad.rawValue | CGEventFlags.maskSecondaryFn.rawValue

    /// True when the Option held in `flags` is the right-hand one (AltGr).
    static func isAltGr(_ flags: CGEventFlags) -> Bool {
        flags.rawValue & 0x40 != 0 && flags.rawValue & 0x20 == 0
    }

    /// Rewrite only the modifiers of an event, e.g. a modifier key press.
    static func setModifiers(_ modifiers: Modifiers, on event: CGEvent) {
        let raw = event.flags.rawValue & ~allModifierBits
        event.flags = CGEventFlags(rawValue: raw | flagBits(for: modifiers))
    }

    /// Rewrite a key event in place so it looks like `stroke` was pressed.
    static func apply(_ stroke: KeyStroke, to event: CGEvent) {
        // F5 → ⌘R must not keep F5's function-key flag, or apps see Fn+⌘R.
        var raw = event.flags.rawValue & ~(allModifierBits | keyTypeBits)
        raw |= flagBits(for: stroke.modifiers) | extraBits(for: stroke.keyCode)
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(stroke.keyCode))
        event.flags = CGEventFlags(rawValue: raw)
    }

    /// Post a brand new key event.
    static func post(_ stroke: KeyStroke, keyDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: stroke.keyCode, keyDown: keyDown) else { return }
        event.flags = CGEventFlags(rawValue: flagBits(for: stroke.modifiers) | extraBits(for: stroke.keyCode))
        event.setIntegerValueField(.eventSourceUserData, value: marker)
        event.post(tap: .cghidEventTap)
    }

    /// Post a press or release of a left-hand modifier key on its own, leaving
    /// the system believing that `nowHeld` are the modifiers down afterwards.
    static func postModifierKey(_ keyCode: UInt16, down: Bool, nowHeld: Modifiers) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else { return }
        event.type = .flagsChanged
        event.flags = CGEventFlags(rawValue: flagBits(for: nowHeld))
        event.setIntegerValueField(.eventSourceUserData, value: marker)
        event.post(tap: .cghidEventTap)
    }
}

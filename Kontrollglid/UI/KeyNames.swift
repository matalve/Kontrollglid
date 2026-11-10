import Carbon.HIToolbox
import Foundation

/// Human readable names for keys and shortcuts, e.g. "⌘⇧Z".
enum KeyNames {
    private static let special: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤",
        114: "Insert", 115: "Home", 116: "Page Up", 117: "⌦", 119: "End", 121: "Page Down",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
    ]

    static func name(_ keyCode: UInt16) -> String {
        special[keyCode] ?? character(for: keyCode)?.uppercased() ?? "Key \(keyCode)"
    }

    static func describe(_ stroke: KeyStroke) -> String {
        var text = ""
        if stroke.modifiers.contains(.control) { text += "⌃" }
        if stroke.modifiers.contains(.option) { text += "⌥" }
        if stroke.modifiers.contains(.shift) { text += "⇧" }
        if stroke.modifiers.contains(.command) { text += "⌘" }
        return text + name(stroke.keyCode)
    }

    /// The character a key produces in the current keyboard layout.
    private static func character(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(
                layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

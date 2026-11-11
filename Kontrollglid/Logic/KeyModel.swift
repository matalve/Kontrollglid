import Foundation

/// The four "real" modifier keys, independent of AppKit/CoreGraphics so the
/// remapping logic can be unit tested without an app host.
struct Modifiers: OptionSet, Codable, Hashable {
    let rawValue: UInt8

    static let control = Modifiers(rawValue: 1 << 0)
    static let option = Modifiers(rawValue: 1 << 1)
    static let shift = Modifiers(rawValue: 1 << 2)
    static let command = Modifiers(rawValue: 1 << 3)
}

/// A key (macOS virtual key code) together with the modifiers held.
struct KeyStroke: Codable, Hashable {
    var keyCode: UInt16
    var modifiers: Modifiers

    init(_ keyCode: UInt16, _ modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// macOS virtual key codes (physical positions, layout independent).
enum KeyCode {
    static let a: UInt16 = 0
    static let isoSection: UInt16 = 10 // "<" on some ISO keyboards
    static let c: UInt16 = 8
    static let v: UInt16 = 9
    static let z: UInt16 = 6
    static let q: UInt16 = 12
    static let w: UInt16 = 13
    static let e: UInt16 = 14
    static let r: UInt16 = 15
    static let y: UInt16 = 16
    static let l: UInt16 = 37
    static let four: UInt16 = 21
    static let five: UInt16 = 23
    static let nine: UInt16 = 25
    static let seven: UInt16 = 26
    static let plus: UInt16 = 27 // "+" on a Swedish layout
    static let eight: UInt16 = 28
    static let zero: UInt16 = 29
    static let grave: UInt16 = 50 // "<" on other ISO keyboards
    static let rightBracket: UInt16 = 30
    static let leftBracket: UInt16 = 33
    static let returnKey: UInt16 = 36
    static let tab: UInt16 = 48
    static let space: UInt16 = 49
    static let backspace: UInt16 = 51
    static let escape: UInt16 = 53
    static let command: UInt16 = 55
    static let control: UInt16 = 59
    static let f5: UInt16 = 96
    static let f13: UInt16 = 105 // Print Screen on PC keyboards
    static let insert: UInt16 = 114 // "Help" on Apple keyboards
    static let home: UInt16 = 115
    static let forwardDelete: UInt16 = 117
    static let f4: UInt16 = 118
    static let end: UInt16 = 119
    static let f2: UInt16 = 120
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126

    static let arrows: Set<UInt16> = [left, right, down, up]

    /// Keys whose real events carry the "function key" flag: the F-row and the
    /// navigation cluster.
    static let functionKeys: Set<UInt16> = Set([
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
        114, 115, 116, 117, 119, 121,
    ]).union(arrows)

    /// Letters, digits, punctuation and Return: the keys where Windows uses
    /// Ctrl and macOS uses Cmd for the same shortcut.
    static let mainBlock: Set<UInt16> = Set(0...47).union([50])
}

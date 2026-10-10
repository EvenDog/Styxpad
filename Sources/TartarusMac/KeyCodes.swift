// A translation table between the two numbering systems for keyboard keys:
// - USB "HID usage" codes: what the Tartarus hardware sends over the cable.
// - Mac "virtual key codes": what macOS uses when we type a key in software.
// It also gives each key a human-readable name for the editor.

import CoreGraphics

/// One keyboard key, known by its name, its Mac key code, and (if it has one) its USB HID code.
struct KeyInfo {
    let name: String
    let macKeyCode: UInt16
    let hidUsage: UInt32?
}

enum KeyCodes {
    static let all: [KeyInfo] = [
        // Letters
        KeyInfo(name: "A", macKeyCode: 0x00, hidUsage: 0x04), KeyInfo(name: "B", macKeyCode: 0x0B, hidUsage: 0x05),
        KeyInfo(name: "C", macKeyCode: 0x08, hidUsage: 0x06), KeyInfo(name: "D", macKeyCode: 0x02, hidUsage: 0x07),
        KeyInfo(name: "E", macKeyCode: 0x0E, hidUsage: 0x08), KeyInfo(name: "F", macKeyCode: 0x03, hidUsage: 0x09),
        KeyInfo(name: "G", macKeyCode: 0x05, hidUsage: 0x0A), KeyInfo(name: "H", macKeyCode: 0x04, hidUsage: 0x0B),
        KeyInfo(name: "I", macKeyCode: 0x22, hidUsage: 0x0C), KeyInfo(name: "J", macKeyCode: 0x26, hidUsage: 0x0D),
        KeyInfo(name: "K", macKeyCode: 0x28, hidUsage: 0x0E), KeyInfo(name: "L", macKeyCode: 0x25, hidUsage: 0x0F),
        KeyInfo(name: "M", macKeyCode: 0x2E, hidUsage: 0x10), KeyInfo(name: "N", macKeyCode: 0x2D, hidUsage: 0x11),
        KeyInfo(name: "O", macKeyCode: 0x1F, hidUsage: 0x12), KeyInfo(name: "P", macKeyCode: 0x23, hidUsage: 0x13),
        KeyInfo(name: "Q", macKeyCode: 0x0C, hidUsage: 0x14), KeyInfo(name: "R", macKeyCode: 0x0F, hidUsage: 0x15),
        KeyInfo(name: "S", macKeyCode: 0x01, hidUsage: 0x16), KeyInfo(name: "T", macKeyCode: 0x11, hidUsage: 0x17),
        KeyInfo(name: "U", macKeyCode: 0x20, hidUsage: 0x18), KeyInfo(name: "V", macKeyCode: 0x09, hidUsage: 0x19),
        KeyInfo(name: "W", macKeyCode: 0x0D, hidUsage: 0x1A), KeyInfo(name: "X", macKeyCode: 0x07, hidUsage: 0x1B),
        KeyInfo(name: "Y", macKeyCode: 0x10, hidUsage: 0x1C), KeyInfo(name: "Z", macKeyCode: 0x06, hidUsage: 0x1D),

        // Number row
        KeyInfo(name: "1", macKeyCode: 0x12, hidUsage: 0x1E), KeyInfo(name: "2", macKeyCode: 0x13, hidUsage: 0x1F),
        KeyInfo(name: "3", macKeyCode: 0x14, hidUsage: 0x20), KeyInfo(name: "4", macKeyCode: 0x15, hidUsage: 0x21),
        KeyInfo(name: "5", macKeyCode: 0x17, hidUsage: 0x22), KeyInfo(name: "6", macKeyCode: 0x16, hidUsage: 0x23),
        KeyInfo(name: "7", macKeyCode: 0x1A, hidUsage: 0x24), KeyInfo(name: "8", macKeyCode: 0x1C, hidUsage: 0x25),
        KeyInfo(name: "9", macKeyCode: 0x19, hidUsage: 0x26), KeyInfo(name: "0", macKeyCode: 0x1D, hidUsage: 0x27),

        // Editing and whitespace
        KeyInfo(name: "Return", macKeyCode: 0x24, hidUsage: 0x28), KeyInfo(name: "Esc", macKeyCode: 0x35, hidUsage: 0x29),
        KeyInfo(name: "Delete", macKeyCode: 0x33, hidUsage: 0x2A), KeyInfo(name: "Tab", macKeyCode: 0x30, hidUsage: 0x2B),
        KeyInfo(name: "Space", macKeyCode: 0x31, hidUsage: 0x2C), KeyInfo(name: "Caps Lock", macKeyCode: 0x39, hidUsage: 0x39),
        KeyInfo(name: "Fwd Delete", macKeyCode: 0x75, hidUsage: 0x4C),

        // Punctuation
        KeyInfo(name: "-", macKeyCode: 0x1B, hidUsage: 0x2D), KeyInfo(name: "=", macKeyCode: 0x18, hidUsage: 0x2E),
        KeyInfo(name: "[", macKeyCode: 0x21, hidUsage: 0x2F), KeyInfo(name: "]", macKeyCode: 0x1E, hidUsage: 0x30),
        KeyInfo(name: "\\", macKeyCode: 0x2A, hidUsage: 0x31), KeyInfo(name: ";", macKeyCode: 0x29, hidUsage: 0x33),
        KeyInfo(name: "'", macKeyCode: 0x27, hidUsage: 0x34), KeyInfo(name: "`", macKeyCode: 0x32, hidUsage: 0x35),
        KeyInfo(name: ",", macKeyCode: 0x2B, hidUsage: 0x36), KeyInfo(name: ".", macKeyCode: 0x2F, hidUsage: 0x37),
        KeyInfo(name: "/", macKeyCode: 0x2C, hidUsage: 0x38),

        // Function keys
        KeyInfo(name: "F1", macKeyCode: 0x7A, hidUsage: 0x3A), KeyInfo(name: "F2", macKeyCode: 0x78, hidUsage: 0x3B),
        KeyInfo(name: "F3", macKeyCode: 0x63, hidUsage: 0x3C), KeyInfo(name: "F4", macKeyCode: 0x76, hidUsage: 0x3D),
        KeyInfo(name: "F5", macKeyCode: 0x60, hidUsage: 0x3E), KeyInfo(name: "F6", macKeyCode: 0x61, hidUsage: 0x3F),
        KeyInfo(name: "F7", macKeyCode: 0x62, hidUsage: 0x40), KeyInfo(name: "F8", macKeyCode: 0x64, hidUsage: 0x41),
        KeyInfo(name: "F9", macKeyCode: 0x65, hidUsage: 0x42), KeyInfo(name: "F10", macKeyCode: 0x6D, hidUsage: 0x43),
        KeyInfo(name: "F11", macKeyCode: 0x67, hidUsage: 0x44), KeyInfo(name: "F12", macKeyCode: 0x6F, hidUsage: 0x45),
        KeyInfo(name: "F13", macKeyCode: 0x69, hidUsage: 0x68), KeyInfo(name: "F14", macKeyCode: 0x6B, hidUsage: 0x69),
        KeyInfo(name: "F15", macKeyCode: 0x71, hidUsage: 0x6A), KeyInfo(name: "F16", macKeyCode: 0x6A, hidUsage: 0x6B),
        KeyInfo(name: "F17", macKeyCode: 0x40, hidUsage: 0x6C), KeyInfo(name: "F18", macKeyCode: 0x4F, hidUsage: 0x6D),
        KeyInfo(name: "F19", macKeyCode: 0x50, hidUsage: 0x6E), KeyInfo(name: "F20", macKeyCode: 0x5A, hidUsage: 0x6F),

        // Navigation
        KeyInfo(name: "Home", macKeyCode: 0x73, hidUsage: 0x4A), KeyInfo(name: "Page Up", macKeyCode: 0x74, hidUsage: 0x4B),
        KeyInfo(name: "End", macKeyCode: 0x77, hidUsage: 0x4D), KeyInfo(name: "Page Down", macKeyCode: 0x79, hidUsage: 0x4E),
        KeyInfo(name: "→", macKeyCode: 0x7C, hidUsage: 0x4F), KeyInfo(name: "←", macKeyCode: 0x7B, hidUsage: 0x50),
        KeyInfo(name: "↓", macKeyCode: 0x7D, hidUsage: 0x51), KeyInfo(name: "↑", macKeyCode: 0x7E, hidUsage: 0x52),

        // Number pad
        KeyInfo(name: "Num /", macKeyCode: 0x4B, hidUsage: 0x54), KeyInfo(name: "Num *", macKeyCode: 0x43, hidUsage: 0x55),
        KeyInfo(name: "Num -", macKeyCode: 0x4E, hidUsage: 0x56), KeyInfo(name: "Num +", macKeyCode: 0x45, hidUsage: 0x57),
        KeyInfo(name: "Num Enter", macKeyCode: 0x4C, hidUsage: 0x58), KeyInfo(name: "Num 1", macKeyCode: 0x53, hidUsage: 0x59),
        KeyInfo(name: "Num 2", macKeyCode: 0x54, hidUsage: 0x5A), KeyInfo(name: "Num 3", macKeyCode: 0x55, hidUsage: 0x5B),
        KeyInfo(name: "Num 4", macKeyCode: 0x56, hidUsage: 0x5C), KeyInfo(name: "Num 5", macKeyCode: 0x57, hidUsage: 0x5D),
        KeyInfo(name: "Num 6", macKeyCode: 0x58, hidUsage: 0x5E), KeyInfo(name: "Num 7", macKeyCode: 0x59, hidUsage: 0x5F),
        KeyInfo(name: "Num 8", macKeyCode: 0x5B, hidUsage: 0x60), KeyInfo(name: "Num 9", macKeyCode: 0x5C, hidUsage: 0x61),
        KeyInfo(name: "Num 0", macKeyCode: 0x52, hidUsage: 0x62), KeyInfo(name: "Num .", macKeyCode: 0x41, hidUsage: 0x63),

        // Modifiers (Windows "Alt" = Mac "Option", Windows "GUI/Win" = Mac "Command")
        KeyInfo(name: "Control", macKeyCode: 0x3B, hidUsage: 0xE0), KeyInfo(name: "Shift", macKeyCode: 0x38, hidUsage: 0xE1),
        KeyInfo(name: "Option", macKeyCode: 0x3A, hidUsage: 0xE2), KeyInfo(name: "Command", macKeyCode: 0x37, hidUsage: 0xE3),
        KeyInfo(name: "Right Control", macKeyCode: 0x3E, hidUsage: 0xE4), KeyInfo(name: "Right Shift", macKeyCode: 0x3C, hidUsage: 0xE5),
        KeyInfo(name: "Right Option", macKeyCode: 0x3D, hidUsage: 0xE6), KeyInfo(name: "Right Command", macKeyCode: 0x36, hidUsage: 0xE7),
    ]

    /// Which modifier "flag" each modifier key turns on while held (e.g. Shift key → shift flag).
    static let modifierFlagForMacKeyCode: [UInt16: CGEventFlags] = [
        0x38: .maskShift, 0x3C: .maskShift,
        0x3B: .maskControl, 0x3E: .maskControl,
        0x3A: .maskAlternate, 0x3D: .maskAlternate,
        0x37: .maskCommand, 0x36: .maskCommand,
    ]

    // Lookup dictionaries built once from the table above, so finding a key is instant.
    private static let byMacKeyCode = Dictionary(all.map { ($0.macKeyCode, $0) }, uniquingKeysWith: { first, _ in first })
    private static let byHIDUsage = Dictionary(all.compactMap { info in info.hidUsage.map { ($0, info) } }, uniquingKeysWith: { first, _ in first })

    /// Returns a readable name for a Mac key code, e.g. 0x0C → "Q".
    static func name(forMacKeyCode code: UInt16) -> String {
        byMacKeyCode[code]?.name ?? "Key \(code)"
    }

    /// Converts what the Tartarus sends (USB HID code) into the Mac key code for the same key.
    static func macKeyCode(forHIDUsage usage: UInt32) -> UInt16? {
        byHIDUsage[usage]?.macKeyCode
    }

    /// Returns a readable name for a USB HID code, e.g. 0x14 → "Q".
    static func name(forHIDUsage usage: UInt32) -> String {
        byHIDUsage[usage]?.name ?? String(format: "HID 0x%02X", usage)
    }
}

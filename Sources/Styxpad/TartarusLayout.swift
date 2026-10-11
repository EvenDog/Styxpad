// Describes the physical keys on the Tartarus Pro: their printed label and which key
// each one sends by factory default. The app recognizes a physical key by that default code.
// If a key turns out to send something different, fix its `defaultHIDUsage` here.

/// One physical key on the Tartarus.
struct PhysicalKey: Identifiable {
    let id: String              // stable name used when saving profiles, e.g. "07" or "dpadUp"
    let label: String           // what the editor shows on the key cap
    let defaultHIDUsage: UInt32 // the USB code the key sends out of the box

    var defaultName: String { KeyCodes.name(forHIDUsage: defaultHIDUsage) }
}

enum TartarusLayout {
    /// The main 4 rows of keys, top to bottom (as seen from above, left hand on the pad).
    static let mainRows: [[PhysicalKey]] = [
        [key("01", 0x1E), key("02", 0x1F), key("03", 0x20), key("04", 0x21), key("05", 0x22)],   // 1 2 3 4 5
        [key("06", 0x2B), key("07", 0x14), key("08", 0x1A), key("09", 0x08), key("10", 0x15)],   // Tab Q W E R
        [key("11", 0x39), key("12", 0x04), key("13", 0x16), key("14", 0x07), key("15", 0x09)],   // Caps A S D F
        [key("16", 0xE1), key("17", 0x1D), key("18", 0x1B), key("19", 0x06)],                   // Shift Z X C
    ]

    // The thumb area.
    static let sideButton = PhysicalKey(id: "side", label: "Side", defaultHIDUsage: 0xE2)      // Alt / Option
    static let thumbKey = PhysicalKey(id: "20", label: "20", defaultHIDUsage: 0x2C)            // Space
    static let dpadUp = PhysicalKey(id: "dpadUp", label: "▲", defaultHIDUsage: 0x52)
    static let dpadDown = PhysicalKey(id: "dpadDown", label: "▼", defaultHIDUsage: 0x51)
    static let dpadLeft = PhysicalKey(id: "dpadLeft", label: "◀", defaultHIDUsage: 0x50)
    static let dpadRight = PhysicalKey(id: "dpadRight", label: "▶", defaultHIDUsage: 0x4F)

    static let allKeys: [PhysicalKey] =
        mainRows.flatMap { $0 } + [sideButton, thumbKey, dpadUp, dpadDown, dpadLeft, dpadRight]

    /// The Tartarus Pro's backlight is one row of 21 lights (per OpenRazer). This says which key
    /// each light sits under, in order: entry 0 = light 0, and so on; nil = not a key we know.
    /// Checked on the real keypad: lights 0–18 = keys 01–19, light 19 = the scroll wheel
    /// (not a key, so nil), light 20 = key 20 (the thumb key).
    static let lightOrder: [String?] =
        (1...19).map { String(format: "%02d", $0) } + [nil, "20"]   // "%02d" = two digits: 1 → "01"

    /// Finds which physical key sent a given USB code (nil if it's not one we know about).
    static func key(forHIDUsage usage: UInt32) -> PhysicalKey? {
        allKeys.first { $0.defaultHIDUsage == usage }
    }

    static func key(withID id: String) -> PhysicalKey? {
        allKeys.first { $0.id == id }
    }

    // Small helper so the rows above stay short: numbered keys use their number as both id and label.
    private static func key(_ number: String, _ usage: UInt32) -> PhysicalKey {
        PhysicalKey(id: number, label: number, defaultHIDUsage: usage)
    }
}

// Builds the messages Razer devices understand for lighting. Razer doesn't document this
// protocol; the byte layout comes from public research by the open-source OpenRazer and
// CommandPost projects, re-implemented here from those facts.
//
// ⚠️ Only add commands known to be safe for the Tartarus Pro. In particular NEVER send
// "set device mode" (command class 0x00, id 0x04): it makes the Tartarus Pro reset itself.

enum RazerProtocol {
    /// Every Razer command is a 90-byte "feature report" (a settings message sent to a USB device).
    static let reportLength = 90

    /// Returns the message that switches the 3 small side lights on or off.
    /// In Razer's protocol the 3 lights are one "side stripe" light (ID 0x0B) whose red, green
    /// and blue values each control one physical light: red → light 1, green → 2, blue → 3.
    static func sideLightsReport(light1: Bool, light2: Bool, light3: Bool) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportLength)
        report[1] = 0x1F   // transaction id the Tartarus Pro expects
        report[5] = 0x09   // number of argument bytes that follow
        report[6] = 0x0F   // command class: "extended matrix" lighting
        report[7] = 0x02   // command id: set effect
        let arguments: [UInt8] = [
            0x01,                    // save to the device's memory, so it survives replugging
            0x0B,                    // which light: the side stripe (the 3 small side lights)
            0x01,                    // effect: static (steady, not blinking)
            0x00, 0x00, 0x01,        // effect settings (unused for static) and number of colors
            light1 ? 0xFF : 0x00,    // "red"   = light 1
            light2 ? 0xFF : 0x00,    // "green" = light 2
            light3 ? 0xFF : 0x00,    // "blue"  = light 3
        ]
        report.replaceSubrange(8..<(8 + arguments.count), with: arguments)
        // Checksum: XOR ("^") of bytes 2 through 87, so the device can detect a damaged message.
        report[88] = report[2...87].reduce(0, ^)
        return report
    }
}

// Builds the messages Razer devices understand for lighting. Razer doesn't document this
// protocol; the byte layout comes from public research by the open-source OpenRazer and
// CommandPost projects, re-implemented here from those facts.
//
// ⚠️ Only add commands known to be safe for the Tartarus Pro. In particular NEVER send
// "set device mode" (command class 0x00, id 0x04): it makes the Tartarus Pro reset itself.

enum RazerProtocol {
    /// Every Razer command is a 90-byte "feature report" (a settings message sent to a USB device).
    static let reportLength = 90

    // Which light a command applies to.
    private static let backlightLED: UInt8 = 0x05
    private static let sideStripeLED: UInt8 = 0x0B   // the 3 small side lights
    private static let saveToDevice: UInt8 = 0x01    // keep the setting after replugging

    /// Returns the message that switches the 3 small side lights on or off.
    /// In Razer's protocol the 3 lights are one "side stripe" light whose red, green and
    /// blue values each control one physical light: red → light 1, green → 2, blue → 3.
    static func sideLightsReport(light1: Bool, light2: Bool, light3: Bool) -> [UInt8] {
        setEffectReport(arguments: [
            saveToDevice, sideStripeLED, 0x01 /* static */, 0x00, 0x00, 0x01 /* one color */,
            light1 ? 0xFF : 0x00, light2 ? 0xFF : 0x00, light3 ? 0xFF : 0x00,
        ])
    }

    /// Returns the message that sets the backlight to the given effect.
    static func backlightEffectReport(_ settings: BacklightSettings) -> [UInt8] {
        let color1 = [settings.color1.red, settings.color1.green, settings.color1.blue]
        let color2 = [settings.color2.red, settings.color2.green, settings.color2.blue]
        // Each effect's arguments: which effect, then its settings, then its colors.
        let effectArguments: [UInt8]
        var transactionID: UInt8 = 0x1F

        switch settings.effect {
        case .off:
            effectArguments = [0x00, 0x00, 0x00, 0x00]
        case .staticColor:
            effectArguments = [0x01, 0x00, 0x00, 0x01] + color1
        case .breathing:
            transactionID = 0x3F   // OpenRazer uses a different transaction id for breathing on this device
            switch settings.colorMode {
            case .single: effectArguments = [0x02, 0x01, 0x00, 0x01] + color1
            case .dual: effectArguments = [0x02, 0x02, 0x00, 0x02] + color1 + color2
            case .random: effectArguments = [0x02, 0x00, 0x00, 0x00]
            }
        case .spectrum:
            effectArguments = [0x03, 0x00, 0x00, 0x00]
        case .wave:
            let direction: UInt8 = settings.direction == .left ? 0x01 : 0x02
            effectArguments = [0x04, direction, 0x28 /* wave speed OpenRazer uses */, 0x00]
        case .reactive:
            effectArguments = [0x05, 0x00, speedByte(settings.speed), 0x01] + color1
        case .starlight:
            let speed = speedByte(settings.speed)
            switch settings.colorMode {
            case .single: effectArguments = [0x07, 0x00, speed, 0x01] + color1
            case .dual: effectArguments = [0x07, 0x00, speed, 0x02] + color1 + color2
            case .random: effectArguments = [0x07, 0x00, speed, 0x00]
            }
        }
        return setEffectReport(arguments: [saveToDevice, backlightLED] + effectArguments,
                               transactionID: transactionID)
    }

    /// Returns the message that sets backlight brightness (0.0 = off, 1.0 = full).
    static func brightnessReport(_ brightness: Double) -> [UInt8] {
        let value = UInt8((min(max(brightness, 0), 1) * 255).rounded())
        // For the Tartarus Pro, brightness uses LED id 0x00 (not the backlight's 0x05).
        return report(commandID: 0x04, arguments: [saveToDevice, 0x00, value])
    }

    /// Reactive and starlight take a speed of 1–3 (OpenRazer doesn't say which end is fast;
    /// we assume 1 = fast).
    private static func speedByte(_ speed: EffectSpeed) -> UInt8 {
        switch speed {
        case .fast: return 0x01
        case .medium: return 0x02
        case .slow: return 0x03
        }
    }

    private static func setEffectReport(arguments: [UInt8], transactionID: UInt8 = 0x1F) -> [UInt8] {
        report(commandID: 0x02, arguments: arguments, transactionID: transactionID)
    }

    /// Builds one 90-byte "extended matrix" lighting command (command class 0x0F).
    private static func report(commandID: UInt8, arguments: [UInt8], transactionID: UInt8 = 0x1F) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportLength)
        report[1] = transactionID
        report[5] = UInt8(arguments.count)   // number of argument bytes
        report[6] = 0x0F                     // command class: "extended matrix" lighting
        report[7] = commandID
        report.replaceSubrange(8..<(8 + arguments.count), with: arguments)
        // Checksum: XOR ("^") of bytes 2 through 87, so the device can detect a damaged message.
        report[88] = report[2...87].reduce(0, ^)
        return report
    }
}

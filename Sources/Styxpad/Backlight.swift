// The backlight settings a profile can have: which lighting effect to show, its colors,
// speed, direction and brightness. RazerProtocol turns these into commands for the Tartarus.

import AppKit
import SwiftUI

/// A color stored as red/green/blue amounts from 0 to 255 (what the Tartarus understands).
struct RGBColor: Codable, Equatable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8

    static let white = RGBColor(red: 255, green: 255, blue: 255)
    static let razerGreen = RGBColor(red: 0, green: 255, blue: 0)
    static let blue = RGBColor(red: 0, green: 0, blue: 255)

    /// Converts to SwiftUI's Color, so the editor's color pickers can show it.
    var swiftUIColor: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Converts from SwiftUI's Color (what the color picker gives us).
    init(_ color: Color) {
        let rgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: Self.byte(rgb.redComponent),
                  green: Self.byte(rgb.greenComponent),
                  blue: Self.byte(rgb.blueComponent))
    }

    /// Turns 0.0–1.0 into 0–255. Clamps first, because UInt8() crashes on out-of-range values
    /// and wide-gamut colors can come back slightly below 0 or above 1.
    private static func byte(_ component: CGFloat) -> UInt8 {
        UInt8((min(max(component, 0), 1) * 255).rounded())
    }
}

/// The lighting effects the Tartarus Pro can show.
enum LightingEffect: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case staticColor = "Static"
    case breathing = "Breathing"
    case spectrum = "Spectrum"
    case wave = "Wave"
    case reactive = "Reactive"
    case starlight = "Starlight"
    case custom = "Custom"         // each key its own color (BacklightSettings.keyColors)
    var id: String { rawValue }

    // Which settings matter for each effect, so the editor only shows relevant controls.
    var usesColorMode: Bool { self == .breathing || self == .starlight }
    var usesSpeed: Bool { self == .reactive || self == .starlight }
    var usesSpeedSlider: Bool { self == .wave }
    var usesDirection: Bool { self == .wave }
    var usesColor: Bool { self == .staticColor || self == .reactive || self == .custom || usesColorMode }
}

/// For effects that support it: one color, two alternating colors, or random colors.
enum ColorMode: String, Codable, CaseIterable, Identifiable {
    case single = "One Color"
    case dual = "Two Colors"
    case random = "Random"
    var id: String { rawValue }
}

enum EffectSpeed: String, Codable, CaseIterable, Identifiable {
    case fast = "Fast"
    case medium = "Medium"
    case slow = "Slow"
    var id: String { rawValue }
}

enum WaveDirection: String, Codable, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    var id: String { rawValue }
}

/// Everything about a profile's backlight.
struct BacklightSettings: Codable, Equatable {
    var effect: LightingEffect = .spectrum
    var color1: RGBColor = .razerGreen
    var color2: RGBColor = .blue          // only used by "Two Colors"
    var colorMode: ColorMode = .single
    var speed: EffectSpeed = .medium
    var direction: WaveDirection = .right
    var brightness: Double = 1.0          // 0.0 (off) to 1.0 (full)
    /// For the Custom effect: each key's color, by physical key id ("01" … "20").
    /// Keys without a color stay dark. Optional, so files saved before this existed still load.
    var keyColors: [String: RGBColor]?
    /// Wave's speed, from 0 (slowest) to 1 (fastest). Optional, so files saved before this existed
    /// still load; nil means defaultWaveSpeed, the speed Styxpad always used before.
    var waveSpeed: Double?

    /// Where the slider sits for the old fixed speed: all the way to Fast (see waveDelay).
    static let defaultWaveSpeed = 1.0

    /// Wave's speed as the byte the Tartarus expects: a delay, so bigger = slower.
    /// Ranges from 160 (slowest) to 40 (fastest: 0x28, what OpenRazer always sends). Shorter
    /// delays (20 and 10) looked glitchy on the real pad, so the slider only slows the wave down.
    /// pow(4, …) makes each step speed up by the same factor.
    var waveDelay: Double { 40 * pow(4, 1 - (waveSpeed ?? Self.defaultWaveSpeed)) }

    /// Whether the effect moves, so the on-screen preview needs to keep redrawing.
    var isAnimated: Bool { effect != .off && effect != .staticColor && effect != .custom }
}

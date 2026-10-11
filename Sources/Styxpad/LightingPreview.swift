// Works out how each key on the on-screen Tartarus should glow, so the editor can preview
// the profile's lighting effect. `time` (in seconds) drives the animated effects.

import SwiftUI

/// How one key glows: its color and how strongly (0 = dark, 1 = full).
struct KeyGlow {
    var color: Color
    var intensity: Double
}

enum LightingPreview {
    /// Returns how a key should glow.
    /// - position: where the key sits horizontally, from 0 (left edge) to 1 (right edge).
    /// - keySeed: a number unique to each key, used to make "random" effects differ per key.
    /// - secondsSincePressed: for Reactive, how long ago the key was pressed (nil = not recently).
    /// - keyID: which key, for the Custom effect's per-key colors.
    static func glow(for settings: BacklightSettings, position: Double, keySeed: Int,
                     time: Double, secondsSincePressed: Double?, keyID: String) -> KeyGlow? {
        let color1 = settings.color1.swiftUIColor
        let color2 = settings.color2.swiftUIColor
        let glow: KeyGlow?

        switch settings.effect {
        case .off:
            glow = nil
        case .staticColor:
            glow = KeyGlow(color: color1, intensity: 1)
        case .custom:
            glow = settings.keyColors?[keyID].map { KeyGlow(color: $0.swiftUIColor, intensity: 1) }
        case .breathing:
            let breathLength = 4.0                                     // seconds per in-and-out
            let level = (1 - cos(time / breathLength * 2 * .pi)) / 2   // smoothly 0 → 1 → 0
            let breathNumber = Int(time / breathLength)
            let color: Color
            switch settings.colorMode {
            case .single: color = color1
            case .dual: color = breathNumber.isMultiple(of: 2) ? color1 : color2
            case .random: color = Color(hue: fraction(Double(breathNumber) * 0.37), saturation: 1, brightness: 1)
            }
            glow = KeyGlow(color: color, intensity: level)
        case .spectrum:
            glow = KeyGlow(color: Color(hue: fraction(time / 10), saturation: 1, brightness: 1), intensity: 1)
        case .wave:
            // A rainbow spread across the keypad, sliding left or right over time.
            // Seconds for the rainbow to slide one full round. Matched by eye to the real pad:
            // at the default delay of 40 it takes about 2.7 seconds.
            let roundLength = settings.waveDelay / 15
            let shift = settings.direction == .right ? -time / roundLength : time / roundLength
            glow = KeyGlow(color: Color(hue: fraction(position * 0.6 + shift), saturation: 1, brightness: 1), intensity: 1)
        case .reactive:
            // A key flashes when pressed and fades out; faster speed = shorter fade.
            let fadeLength = settings.speed == .fast ? 0.5 : settings.speed == .medium ? 1.0 : 2.0
            if let age = secondsSincePressed, age < fadeLength {
                glow = KeyGlow(color: color1, intensity: 1 - age / fadeLength)
            } else {
                glow = nil
            }
        case .starlight:
            // Each key twinkles on its own schedule, picked "randomly" from its seed.
            let twinkleLength = settings.speed == .fast ? 1.0 : settings.speed == .medium ? 2.0 : 3.5
            let offset = fraction(sin(Double(keySeed) * 12.9898) * 43758.5453)   // a stable pseudo-random 0…1
            let cycle = (time / twinkleLength) + offset * 3
            let twinkleNumber = Int(cycle)
            let level = max(0, sin(fraction(cycle) * .pi))                         // rises and falls once per cycle
            let isLit = fraction(sin(Double(keySeed * 31 + twinkleNumber) * 78.233) * 9631.17) < 0.35
            let color: Color
            switch settings.colorMode {
            case .single: color = color1
            case .dual: color = twinkleNumber.isMultiple(of: 2) ? color1 : color2
            case .random: color = Color(hue: fraction(Double(keySeed * 7 + twinkleNumber) * 0.29), saturation: 1, brightness: 1)
            }
            glow = isLit ? KeyGlow(color: color, intensity: level) : nil
        }

        // Apply the profile's brightness setting on top.
        guard var result = glow else { return nil }
        result.intensity *= settings.brightness
        return result
    }

    /// The part after the decimal point, always 0…1 (e.g. 2.75 → 0.75, -0.25 → 0.75).
    private static func fraction(_ value: Double) -> Double {
        value - floor(value)
    }
}

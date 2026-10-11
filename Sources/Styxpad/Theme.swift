// The "Styx" look: deep ink-blue surfaces, a river-teal accent, and Optima (a classical,
// carved-looking typeface that ships with every Mac) for the wordmark and numerals.
// Keeping colors here means the whole app can be restyled in one place.

import SwiftUI

enum Theme {
    // Surfaces, darkest to lightest.
    static let ink = Color(hex: 0x0A0F1A)          // window background
    static let bar = Color(hex: 0x0C1220)          // title bar area
    static let panel = Color(hex: 0x0F1626)        // cards and panels
    static let raised = Color(hex: 0x121A2C)       // controls sitting on panels
    static let border = Color(hex: 0x1C2740)
    static let borderStrong = Color(hex: 0x24314D)

    // Text.
    static let text = Color(hex: 0xE6EDF7)
    static let textSecondary = Color(hex: 0xB4C0D4)
    static let textMuted = Color(hex: 0x8B9AB3)

    // The accent: the river Styx.
    static let river = Color(hex: 0x5EEAD4)
    static let riverInk = Color(hex: 0x06201B)     // text on top of the river color
    static let riverDeep = Color(hex: 0x10262A)    // tinted background for selected things

    /// Optima for the wordmark, section labels and profile numerals.
    static func display(_ size: CGFloat) -> Font {
        .custom("Optima", size: size).weight(.bold)
    }
}

extension Color {
    /// Makes a color from a hex number like 0x5EEAD4 (the way designers usually write colors).
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Roman numerals for profile numbers: 1 → I, 2 → II … 6 → VI.
func romanNumeral(_ number: Int) -> String {
    ["I", "II", "III", "IV", "V", "VI"][min(max(number, 1), 6) - 1]
}

/// The rounded "pill" buttons used throughout the Styx look.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: prominent ? .bold : .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(prominent ? Theme.riverInk : Theme.text)
            .background(
                Capsule().fill(prominent ? Theme.river : Color.clear)
            )
            .overlay(Capsule().strokeBorder(prominent ? Color.clear : Theme.borderStrong))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

/// A row of pill-shaped choices (like a segmented control), in the Styx look.
struct PillPicker<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isSelected ? Theme.borderStrong : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.raised))
        .overlay(Capsule().strokeBorder(Theme.border))
    }
}

/// The thin wavy "river" line under the title bar.
struct RiverLine: View {
    var body: some View {
        // A gentle wave drawn across the full width, scaled to whatever width the window has.
        Canvas { context, size in
            var path = Path()
            let midY = size.height / 2
            path.move(to: CGPoint(x: 0, y: midY))
            let waves = 8
            let step = size.width / CGFloat(waves)
            for i in 0..<waves {
                let x = CGFloat(i) * step
                let dy: CGFloat = i.isMultiple(of: 2) ? -3 : 3
                path.addQuadCurve(to: CGPoint(x: x + step, y: midY),
                                  control: CGPoint(x: x + step / 2, y: midY + dy))
            }
            context.stroke(path, with: .color(Theme.river.opacity(0.55)), lineWidth: 1.2)
        }
        .frame(height: 10)
        .background(Theme.bar)
    }
}

// The lighting panel: choose the active profile's backlight effect, colors, speed, direction
// and brightness. Only the controls that matter for the chosen effect appear.

import SwiftUI

struct LightingEditorView: View {
    let profileTitle: String
    @Binding var settings: BacklightSettings

    /// Ready-made colors offered as swatches (plus a custom color picker).
    private let swatches: [(name: String, color: RGBColor)] = [
        ("Teal", RGBColor(red: 0x5E, green: 0xEA, blue: 0xD4)),
        ("Sky", RGBColor(red: 0x7D, green: 0xD3, blue: 0xFC)),
        ("Violet", RGBColor(red: 0xA7, green: 0x8B, blue: 0xFA)),
        ("Ember", RGBColor(red: 0xFB, green: 0x92, blue: 0x3C)),
        ("Green", RGBColor(red: 0x3D, green: 0xDC, blue: 0x84)),
        ("White", RGBColor(red: 0xF1, green: 0xF5, blue: 0xF9)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BACKLIGHT")
                    .font(Theme.display(12))
                    .tracking(2.6)
                    .foregroundStyle(Theme.textMuted)
                Text(profileTitle)
                    .font(.system(size: 17, weight: .bold))
            }

            section("Effect") {
                // A 3-column grid of effect buttons.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(LightingEffect.allCases) { effect in
                        let isSelected = settings.effect == effect
                        Button {
                            settings.effect = effect
                            // Starting Custom for the first time: give every key the current color.
                            if effect == .custom && settings.keyColors == nil { fillAllKeys() }
                        } label: {
                            Text(effect.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Theme.riverDeep : Color.clear))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Theme.river : Theme.borderStrong))
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if settings.effect.usesColorMode {
                section("Colors") {
                    PillPicker(options: ColorMode.allCases.map { ($0.rawValue, $0) }, selection: $settings.colorMode)
                }
            }

            // Colors: hidden for random mode and for effects that pick their own colors.
            if settings.effect.usesColor && !(settings.effect.usesColorMode && settings.colorMode == .random) {
                section(colorSectionTitle) {
                    swatchRow(for: \.color1)
                }
                if settings.effect == .custom {
                    HStack(spacing: 12) {
                        Button("Fill All") { fillAllKeys() }
                            .buttonStyle(PillButtonStyle())
                            .fixedSize()
                        Text("Click keys on the drawing to paint them.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if settings.effect.usesColorMode && settings.colorMode == .dual {
                    section("Second color") {
                        swatchRow(for: \.color2)
                    }
                }
            }

            if settings.effect.usesSpeed {
                section("Speed") {
                    PillPicker(options: EffectSpeed.allCases.map { ($0.rawValue, $0) }, selection: $settings.speed)
                }
            }

            if settings.effect.usesDirection {
                section("Direction") {
                    PillPicker(options: WaveDirection.allCases.map { ($0.rawValue, $0) }, selection: $settings.direction)
                }
            }

            if settings.effect != .off {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Brightness").foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(Int((settings.brightness * 100).rounded()))%").foregroundStyle(Theme.textMuted)
                    }
                    Slider(value: $settings.brightness, in: 0...1)
                        .tint(Theme.river)
                        .accessibilityLabel("Brightness")
                }
            }

            Text("The side lights always show which profile is active.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
    }

    /// A titled group of controls.
    private var colorSectionTitle: String {
        if settings.effect == .custom { return "Paint color" }
        return settings.colorMode == .dual && settings.effect.usesColorMode ? "First color" : "Color"
    }

    /// Custom effect: gives every key that has a light the current paint color.
    private func fillAllKeys() {
        let keyIDs = TartarusLayout.lightOrder.compactMap { $0 }   // compactMap drops the nils
        settings.keyColors = Dictionary(uniqueKeysWithValues: keyIDs.map { ($0, settings.color1) })
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    /// Round color swatches plus the system color picker for any other color.
    /// `\.color1` is a "key path": a reference to a property, so one function serves both colors.
    private func swatchRow(for keyPath: WritableKeyPath<BacklightSettings, RGBColor>) -> some View {
        HStack(spacing: 10) {
            ForEach(swatches, id: \.name) { swatch in
                let isSelected = settings[keyPath: keyPath] == swatch.color
                Button { settings[keyPath: keyPath] = swatch.color } label: {
                    Circle()
                        .fill(swatch.color.swiftUIColor)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(Theme.text, lineWidth: isSelected ? 2 : 0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.name)
                .help(swatch.name)
            }
            ColorPicker("Custom color", selection: Binding(
                get: { settings[keyPath: keyPath].swiftUIColor },
                set: { settings[keyPath: keyPath] = RGBColor($0) }
            ), supportsOpacity: false)
            .labelsHidden()
            .help("Pick any color")
        }
    }
}

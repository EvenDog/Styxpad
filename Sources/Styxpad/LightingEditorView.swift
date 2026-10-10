// The "Lighting" tab of the editor: choose the active profile's backlight effect, colors,
// speed, direction and brightness. Only the controls that matter for the chosen effect appear.

import SwiftUI

struct LightingEditorView: View {
    @Binding var settings: BacklightSettings

    var body: some View {
        // "Form" lays out labeled controls in neat aligned rows, like System Settings.
        Form {
            Picker("Effect", selection: $settings.effect) {
                ForEach(LightingEffect.allCases) { Text($0.rawValue).tag($0) }
            }

            if settings.effect.usesColorMode {
                Picker("Colors", selection: $settings.colorMode) {
                    ForEach(ColorMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            // Colors: hidden for random mode and for effects that pick their own colors.
            if settings.effect.usesColor && !(settings.effect.usesColorMode && settings.colorMode == .random) {
                ColorPicker("Color", selection: colorBinding(\.color1), supportsOpacity: false)
                if settings.effect.usesColorMode && settings.colorMode == .dual {
                    ColorPicker("Second color", selection: colorBinding(\.color2), supportsOpacity: false)
                }
            }

            if settings.effect.usesSpeed {
                Picker("Speed", selection: $settings.speed) {
                    ForEach(EffectSpeed.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if settings.effect.usesDirection {
                Picker("Direction", selection: $settings.direction) {
                    ForEach(WaveDirection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if settings.effect != .off {
                Slider(value: $settings.brightness, in: 0...1) {
                    Text("Brightness")
                }
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    /// The color pickers work with SwiftUI's Color, so convert to/from our RGBColor.
    /// `\.color1` is a "key path": a reference to a property, so one function serves both colors.
    private func colorBinding(_ keyPath: WritableKeyPath<BacklightSettings, RGBColor>) -> Binding<Color> {
        Binding(
            get: { settings[keyPath: keyPath].swiftUIColor },
            set: { settings[keyPath: keyPath] = RGBColor($0) }
        )
    }
}

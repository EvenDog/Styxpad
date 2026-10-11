// Draws the Tartarus Pro the way it looks from above (traced from a photo): staggered key
// columns, the palm rest, the scroll wheel, and the thumb module with the 3 side lights, the
// round Side button, the D-pad and the angled key 20. Keys glow with the profile's lighting,
// light up while pressed, and open a popover (supplied by the caller) when clicked.

import SwiftUI

/// Where everything sits, measured in a 445 × 665 grid traced from the photo.
/// The drawing is scaled up or down from these numbers to fit the window.
enum PadGeometry {
    static let size = CGSize(width: 445, height: 665)
    static let keySize = CGSize(width: 55, height: 46)
    /// Left edge of each key column.
    static let columnX: [CGFloat] = [27, 87, 152, 215, 278]
    /// Top edge of each key in each column — the columns are staggered: the left one sits
    /// lowest and each column to the right sits a little higher.
    static let columnY: [[CGFloat]] = [
        [43, 103, 160, 220],
        [27, 85, 145, 205],
        [23, 80, 140, 200],
        [23, 80, 140, 200],
        [23, 80, 137],
    ]
    static let wheel = CGRect(x: 290, y: 214, width: 26, height: 80)
    static let sideLights = CGPoint(x: 408, y: 160)
    static let sideButton = CGRect(x: 371, y: 279, width: 32, height: 32)
    static let dpad = CGRect(x: 371, y: 304, width: 70, height: 70)
    static let thumbKey = CGRect(x: 338, y: 408, width: 100, height: 56)
    static let thumbKeyAngle = -12.0
}

struct DeviceView<Popover: View>: View {
    let profile: Profile
    /// Which layer's mappings to print on the keys.
    let layer: Layer
    let pressedKeyIDs: Set<String>
    /// The active profile's position in the list, which picks the side-light pattern (nil = all off).
    let activeProfileIndex: Int?
    /// How big to draw it: 1 = the traced size (445 × 665 points).
    let scale: CGFloat
    /// Seconds (any steadily increasing clock); drives animated lighting previews.
    var time: Double = 0
    /// When each key was last pressed (same clock as `time`), for the Reactive preview.
    var lastPressTimes: [String: Double] = [:]
    /// The macro library, so keys that run a macro can show its name.
    var macros: [Macro] = []
    @Binding var selectedKeyID: String?
    /// The popover shown next to a key when it's selected.
    @ViewBuilder let popover: (PhysicalKey) -> Popover

    var body: some View {
        let s = scale
        ZStack(alignment: .topLeading) {
            PadBodyShape()
                .fill(LinearGradient(colors: [Color(hex: 0x23252C), Color(hex: 0x121318)], startPoint: .top, endPoint: .bottom))
                .overlay(PadBodyShape().stroke(.white.opacity(0.10), lineWidth: 1))
            // The recessed well the keys sit in.
            RoundedRectangle(cornerRadius: 10 * s)
                .fill(Color(hex: 0x0C0D10).opacity(0.55))
                .frame(width: 320 * s, height: 262 * s)
                .offset(x: 18 * s, y: 18 * s)
            palmRest
            PodShape()
                .fill(LinearGradient(colors: [Color(hex: 0x25272E), Color(hex: 0x121318)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(PodShape().stroke(.white.opacity(0.10), lineWidth: 1))

            mainKeys
            scrollWheel
            sideLights
            sideButton
            dpad
            thumbKey
        }
        .frame(width: PadGeometry.size.width * s, height: PadGeometry.size.height * s, alignment: .topLeading)
    }

    // MARK: Parts

    private var palmRest: some View {
        let s = scale
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 46 * s, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1D1F25), Color(hex: 0x101115)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 46 * s, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
            // The crease across the palm rest.
            Path { path in
                path.move(to: CGPoint(x: 14 * s, y: 164 * s))
                path.addQuadCurve(to: CGPoint(x: 308 * s, y: 164 * s), control: CGPoint(x: 161 * s, y: 130 * s))
            }
            .stroke(.white.opacity(0.10), lineWidth: 2)
        }
        .frame(width: 322 * s, height: 328 * s)
        .offset(y: 336 * s)
    }

    private var mainKeys: some View {
        ForEach(Array(TartarusLayout.mainRows.enumerated()), id: \.offset) { row, keys in
            ForEach(Array(keys.enumerated()), id: \.element.id) { column, key in
                let origin = CGPoint(x: PadGeometry.columnX[column], y: PadGeometry.columnY[column][row])
                keyCap(key, frame: CGRect(origin: origin, size: PadGeometry.keySize),
                       popoverEdge: column <= 2 ? .leading : .trailing)
            }
        }
    }

    private var scrollWheel: some View {
        let s = scale
        let glow = glow(forLightID: TartarusLayout.wheelLightID, x: PadGeometry.wheel.midX)
        // Up, Click and Down, top to bottom: each its own clickable zone, like the d-pad's arrows.
        let zones: [(PhysicalKey, String)] = [
            (TartarusLayout.wheelUp, "arrowtriangle.up.fill"),
            (TartarusLayout.wheelClick, "circle.fill"),
            (TartarusLayout.wheelDown, "arrowtriangle.down.fill"),
        ]
        return RoundedRectangle(cornerRadius: 13 * s)
            .fill(LinearGradient(colors: [Color(hex: 0x15161A), Color(hex: 0x2B2D34), Color(hex: 0x15161A)], startPoint: .leading, endPoint: .trailing))
            .overlay(
                Capsule()
                    .fill((glow?.color ?? .white).opacity(0.15 + 0.85 * (glow?.intensity ?? 0)))
                    .frame(width: 4 * s, height: 60 * s)
                    .shadow(color: glow?.color.opacity(glow?.intensity ?? 0) ?? .clear, radius: 6)
            )
            .overlay {
                VStack(spacing: 0) {
                    ForEach(zones, id: \.0.id) { key, icon in
                        let isCustom = profile.action(for: key.id, in: layer) != nil
                        Image(systemName: icon)
                            .font(.system(size: (key.id == TartarusLayout.wheelClick.id ? 5 : 8) * s))
                            .foregroundStyle(isCustom ? Theme.river : .white.opacity(0.75))
                            .shadow(color: .black, radius: 1.5)   // stays readable on top of the lit strip
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .modifier(KeyInteraction(key: key, isSelected: selectedKeyID == key.id, isPressed: false,
                                                     shape: RoundedRectangle(cornerRadius: 6 * s), popoverEdge: .trailing,
                                                     selectedKeyID: $selectedKeyID, popover: popover))
                            .help("\(key.label): \(mappingText(for: key)) (\(key.defaultName) by default)")
                    }
                }
            }
            .frame(width: PadGeometry.wheel.width * s, height: PadGeometry.wheel.height * s)
            .offset(x: PadGeometry.wheel.minX * s, y: PadGeometry.wheel.minY * s)
    }

    private var sideLights: some View {
        let s = scale
        let colors: [Color] = [.orange, .green, .blue]
        let patterns = TartarusLayout.profileLightPatterns
        let pattern = activeProfileIndex.map { patterns[$0 % patterns.count] }
        return VStack(spacing: 9 * s) {
            ForEach(0..<3, id: \.self) { index in
                let isOn = pattern?[index] == true
                Capsule()
                    .fill(isOn ? colors[index] : Color(hex: 0x33353C))
                    .frame(width: 11 * s, height: 3 * s)
                    .shadow(color: isOn ? colors[index] : .clear, radius: 4)
            }
        }
        .offset(x: PadGeometry.sideLights.x * s, y: PadGeometry.sideLights.y * s)
        .help("Side lights — show which profile is active")
    }

    private var sideButton: some View {
        let s = scale
        let key = TartarusLayout.sideButton
        // The Hypershift layer falls back to the Normal mapping when it has none of its own.
        let action = profile.action(for: key.id, in: layer) ?? profile.action(for: key.id, in: .normal)
        let glow = glow(for: key, x: PadGeometry.sideButton.midX)
        return Circle()
            .fill(LinearGradient(colors: [Color(hex: 0x34363E), Color(hex: 0x1C1D22)], startPoint: .top, endPoint: .bottom))
            .overlay(Circle().strokeBorder((glow?.color ?? .white).opacity(0.12 + 0.45 * (glow?.intensity ?? 0))))
            .overlay {
                if action?.command == .nextProfile {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12 * s, weight: .semibold))
                        .foregroundStyle(Theme.river)
                } else {
                    Text(mappingText(for: key))
                        .font(.system(size: 9 * s, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .minimumScaleFactor(0.5)
                        .padding(3 * s)
                }
            }
            .shadow(color: (glow?.color ?? .clear).opacity(0.4 * (glow?.intensity ?? 0)), radius: 6)
            .modifier(KeyInteraction(key: key, isSelected: selectedKeyID == key.id, isPressed: pressedKeyIDs.contains(key.id),
                                     shape: Circle(), popoverEdge: .trailing, selectedKeyID: $selectedKeyID, popover: popover))
            .frame(width: PadGeometry.sideButton.width * s, height: PadGeometry.sideButton.height * s)
            .offset(x: PadGeometry.sideButton.minX * s, y: PadGeometry.sideButton.minY * s)
    }

    private var dpad: some View {
        let s = scale
        let center = CGPoint(x: PadGeometry.dpad.midX, y: PadGeometry.dpad.midY)
        let glow = glow(for: TartarusLayout.dpadUp, x: center.x)
        // The four directions, each its own remappable key: (key, offset from center, arrow icon).
        let directions: [(PhysicalKey, CGSize, String)] = [
            (TartarusLayout.dpadUp, CGSize(width: 0, height: -22), "arrowtriangle.up.fill"),
            (TartarusLayout.dpadDown, CGSize(width: 0, height: 22), "arrowtriangle.down.fill"),
            (TartarusLayout.dpadLeft, CGSize(width: -22, height: 0), "arrowtriangle.left.fill"),
            (TartarusLayout.dpadRight, CGSize(width: 22, height: 0), "arrowtriangle.right.fill"),
        ]
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x383A42), Color(hex: 0x17181C)], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: 35 * s))
                .overlay(Circle().strokeBorder((glow?.color ?? .white).opacity(0.12 + 0.45 * (glow?.intensity ?? 0))))
                .shadow(color: (glow?.color ?? .clear).opacity(0.4 * (glow?.intensity ?? 0)), radius: 7)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x2B2D33), Color(hex: 0x15161A)], startPoint: .top, endPoint: .bottom))
                .frame(width: 26 * s, height: 26 * s)
            ForEach(directions, id: \.0.id) { key, offset, icon in
                let isCustom = profile.action(for: key.id, in: layer) != nil
                Image(systemName: icon)
                    .font(.system(size: 9 * s))
                    .foregroundStyle(isCustom ? Theme.river : .white.opacity(0.75))
                    .frame(width: 22 * s, height: 20 * s)
                    .background(pressedKeyIDs.contains(key.id) ? Color.white.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5 * s))
                    .modifier(KeyInteraction(key: key, isSelected: selectedKeyID == key.id, isPressed: false,
                                             shape: RoundedRectangle(cornerRadius: 5 * s), popoverEdge: .trailing,
                                             selectedKeyID: $selectedKeyID, popover: popover))
                    .help("\(mappingText(for: key)) (\(key.defaultName) by default)")
                    .offset(x: offset.width * s, y: offset.height * s)
            }
        }
        .frame(width: PadGeometry.dpad.width * s, height: PadGeometry.dpad.height * s)
        .offset(x: PadGeometry.dpad.minX * s, y: PadGeometry.dpad.minY * s)
    }

    private var thumbKey: some View {
        keyCap(TartarusLayout.thumbKey, frame: PadGeometry.thumbKey, popoverEdge: .trailing,
               angle: PadGeometry.thumbKeyAngle)
    }

    // MARK: Helpers

    private func keyCap(_ key: PhysicalKey, frame: CGRect, popoverEdge: Edge, angle: Double = 0) -> some View {
        let s = scale
        let isHypershiftKey = key.id == profile.hypershiftKeyID
        return KeyCapView(
            number: key.label,
            mapping: mappingText(for: key),
            isCustom: profile.action(for: key.id, in: layer) != nil || isHypershiftKey,
            isPressed: pressedKeyIDs.contains(key.id),
            glow: glow(for: key, x: frame.midX),
            scale: s
        )
        .modifier(KeyInteraction(key: key, isSelected: selectedKeyID == key.id, isPressed: false,
                                 shape: RoundedRectangle(cornerRadius: 8 * s, style: .continuous),
                                 popoverEdge: popoverEdge, selectedKeyID: $selectedKeyID, popover: popover))
        .frame(width: frame.width * s, height: frame.height * s)
        .rotationEffect(.degrees(angle))
        .offset(x: frame.minX * s, y: frame.minY * s)
    }

    /// What to print on a key for the current layer.
    private func mappingText(for key: PhysicalKey) -> String {
        if key.id == profile.hypershiftKeyID { return "Hypershift" }
        if let action = profile.action(for: key.id, in: layer) { return action.displayName(macros: macros) }
        if layer == .hypershift, let normal = profile.action(for: key.id, in: .normal) {
            return normal.displayName(macros: macros)   // the Hypershift layer falls back to Normal
        }
        return key.defaultName
    }

    private func glow(for key: PhysicalKey, x: CGFloat) -> KeyGlow? {
        glow(forLightID: key.id, x: x)
    }

    /// Same, by id, so lights that aren't keys (the scroll wheel) can glow too.
    private func glow(forLightID id: String, x: CGFloat) -> KeyGlow? {
        let keySeed = TartarusLayout.allKeys.firstIndex { $0.id == id } ?? TartarusLayout.allKeys.count
        return LightingPreview.glow(
            for: profile.backlight ?? BacklightSettings(),
            position: Double(x / PadGeometry.size.width), keySeed: keySeed, time: time,
            secondsSincePressed: lastPressTimes[id].map { time - $0 },
            keyID: id
        )
    }
}

/// Makes a key clickable: shows the selection ring and opens the popover next to it.
private struct KeyInteraction<KeyShape: InsettableShape, Popover: View>: ViewModifier {
    let key: PhysicalKey
    let isSelected: Bool
    let isPressed: Bool
    let shape: KeyShape
    let popoverEdge: Edge
    @Binding var selectedKeyID: String?
    let popover: (PhysicalKey) -> Popover

    func body(content: Content) -> some View {
        content
            .overlay(shape.inset(by: -3).strokeBorder(Theme.river, lineWidth: 2.5).opacity(isSelected ? 1 : 0))
            .contentShape(shape)
            .onTapGesture { selectedKeyID = key.id }
            // A native macOS popover, with its arrow pointing at this key.
            .popover(isPresented: Binding(get: { isSelected },
                                          set: { if !$0 && isSelected { selectedKeyID = nil } }),
                     arrowEdge: popoverEdge) {
                popover(key)
            }
    }
}

/// One keycap: dark, slightly domed, with an underglow from the lighting preview.
struct KeyCapView: View {
    let number: String
    let mapping: String
    let isCustom: Bool     // has a custom mapping in this layer
    let isPressed: Bool    // physically held down right now
    let glow: KeyGlow?
    let scale: CGFloat

    var body: some View {
        let s = scale
        let shape = RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
        let glowStrength = glow?.intensity ?? 0
        ZStack {
            shape.fill(LinearGradient(
                colors: isPressed ? [Color(hex: 0x4A4C55), Color(hex: 0x2E3038)] : [Color(hex: 0x34363E), Color(hex: 0x1F2026)],
                startPoint: .top, endPoint: .bottom))
            // A thin rim, lit in the backlight color like the real keycaps' edges.
            shape.strokeBorder((glow?.color ?? .white).opacity(0.10 + 0.40 * glowStrength), lineWidth: 1)
            VStack(spacing: 1 * s) {
                Text(number)
                    .font(.system(size: 8.5 * s, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                Text(mapping)
                    .font(.system(size: 12 * s, weight: isCustom ? .bold : .medium))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 4 * s)
            if isCustom {
                // Small dot: "this key has a custom mapping".
                Circle()
                    .fill(Theme.river)
                    .frame(width: 5 * s, height: 5 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(5 * s)
            }
        }
        .shadow(color: (glow?.color ?? .clear).opacity(0.45 * glowStrength), radius: 7 * s, y: -2 * s)   // underglow
        .shadow(color: .black.opacity(0.55), radius: 2, y: 2)
        .offset(y: isPressed ? 1.5 : 0)
        .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

/// The main body plate (keys area) and the neck down to the palm rest, in the 445 × 665 grid.
private struct PadBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / PadGeometry.size.width
        var path = Path()
        path.move(to: CGPoint(x: 2, y: 18))
        path.addQuadCurve(to: CGPoint(x: 17, y: 3), control: CGPoint(x: 2, y: 3))
        path.addLine(to: CGPoint(x: 338, y: 3))
        path.addQuadCurve(to: CGPoint(x: 352, y: 17), control: CGPoint(x: 352, y: 3))
        path.addLine(to: CGPoint(x: 352, y: 330))
        path.addQuadCurve(to: CGPoint(x: 332, y: 354), control: CGPoint(x: 352, y: 352))
        path.addLine(to: CGPoint(x: 34, y: 354))
        path.addQuadCurve(to: CGPoint(x: 17, y: 338), control: CGPoint(x: 20, y: 352))
        path.addLine(to: CGPoint(x: 2, y: 272))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: s, y: s))
    }
}

/// The thumb module on the right side, in the 445 × 665 grid.
private struct PodShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / PadGeometry.size.width
        var path = Path()
        path.move(to: CGPoint(x: 362, y: 142))
        path.addQuadCurve(to: CGPoint(x: 394, y: 112), control: CGPoint(x: 364, y: 112))
        path.addQuadCurve(to: CGPoint(x: 429, y: 142), control: CGPoint(x: 422, y: 114))
        path.addLine(to: CGPoint(x: 441, y: 330))
        path.addQuadCurve(to: CGPoint(x: 400, y: 392), control: CGPoint(x: 445, y: 388))
        path.addQuadCurve(to: CGPoint(x: 350, y: 342), control: CGPoint(x: 352, y: 394))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: s, y: s))
    }
}

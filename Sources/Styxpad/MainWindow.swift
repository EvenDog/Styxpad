// The main window, built around a drawing of the Tartarus:
// - the title bar holds the STYXPAD wordmark, the profile switcher (I · II · III),
//   the Keys / Lighting switch and a connection dot;
// - Keys: click a key on the drawing and a popover next to it lets you change it;
// - Lighting: the profile's backlight effect, colors and brightness, previewed on the drawing.

import SwiftUI

enum EditorTab: String, CaseIterable {
    case keys = "Keys"
    case lighting = "Lighting"
}

struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: EditorTab = .keys

    var body: some View {
        VStack(spacing: 0) {
            RiverLine()
            if !model.isConnected {
                ConnectionBanner()
            }
            switch tab {
            case .keys: KeysScreen()
            case .lighting: LightingScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink)
        .foregroundStyle(Theme.text)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text("STYXPAD")
                    .font(Theme.display(17))
                    .tracking(3.5)
                    .padding(.leading, 8)
            }
            ToolbarItem(placement: .principal) {
                ProfileSwitcher()
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 14) {
                    PillPicker(options: EditorTab.allCases.map { ($0.rawValue, $0) }, selection: $tab)
                    ConnectionDot()
                }
            }
        }
        .toolbarBackground(Theme.bar, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .preferredColorScheme(.dark)   // the Styx look is always dark
        .frame(minWidth: 940, minHeight: 720)
    }
}

// MARK: - Title bar pieces

/// The I · II · III profile pills. Right-click one to rename or delete it.
struct ProfileSwitcher: View {
    @Environment(AppModel.self) private var model
    @State private var renamingProfileID: UUID?
    @State private var renameText = ""

    var body: some View {
        @Bindable var store = model.store

        HStack(spacing: 0) {
            ForEach(Array(store.profiles.enumerated()), id: \.element.id) { index, profile in
                let isActive = profile.id == store.activeProfileID
                Button { store.activeProfileID = profile.id } label: {
                    HStack(spacing: 7) {
                        Text(romanNumeral(index + 1))
                            .font(Theme.display(13))
                            .foregroundStyle(isActive ? Theme.riverInk : Theme.textMuted)
                        Text(profile.name.isEmpty ? "Untitled" : profile.name)
                            .font(.system(size: 13, weight: isActive ? .bold : .medium))
                            .foregroundStyle(isActive ? Theme.riverInk : Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(isActive ? Theme.river : Color.clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Rename…") {
                        renameText = profile.name
                        renamingProfileID = profile.id
                    }
                    Button("Delete", role: .destructive) { store.deleteProfile(profile.id) }
                        .disabled(store.profiles.count < 2)
                }
                .help("Profile \(romanNumeral(index + 1)) — side light \(index + 1). Right-click to rename or delete.")
            }
            if store.profiles.count < ProfileStore.maxProfiles {
                Button { store.addProfile() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 26)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("New profile (up to \(ProfileStore.maxProfiles), one for each side light)")
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.raised))
        .overlay(Capsule().strokeBorder(Theme.border))
        .alert("Rename Profile", isPresented: Binding(get: { renamingProfileID != nil },
                                                    set: { if !$0 { renamingProfileID = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let index = store.profiles.firstIndex(where: { $0.id == renamingProfileID }) {
                    store.profiles[index].name = renameText
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// A small glowing dot: teal when the Tartarus is connected, grey when not.
struct ConnectionDot: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Circle()
            .fill(model.isConnected ? Theme.river : Theme.textMuted.opacity(0.5))
            .frame(width: 8, height: 8)
            .shadow(color: model.isConnected ? Theme.river : .clear, radius: 4)
            .help(model.isConnected ? "Tartarus Pro connected" : model.statusText)
            .accessibilityLabel(model.isConnected ? "Tartarus Pro connected" : "Tartarus not connected")
    }
}

/// Shown under the title bar when the Tartarus isn't connected, explaining why.
struct ConnectionBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(model.statusText)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if !Permissions.canReadInput || !Permissions.canSendKeys {
                Button("Grant Permissions…") { Permissions.openSettings() }
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Theme.panel)
    }
}

// MARK: - Keys

struct KeysScreen: View {
    @Environment(AppModel.self) private var model
    @State private var selectedKeyID: String?
    @State private var layer: Layer = .normal

    var body: some View {
        @Bindable var store = model.store

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PillPicker(options: Layer.allCases.map { ($0.rawValue, $0) }, selection: $layer)
                if model.isHypershiftHeld {
                    Text("HYPERSHIFT ACTIVE")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.river))
                        .foregroundStyle(Theme.riverInk)
                }
                Spacer()
                Text("Click a key to change what it does.")
                    .foregroundStyle(Theme.textMuted)
            }

            GeometryReader { geometry in
                let scale = fitScale(for: geometry.size)
                LiveClock(isAnimated: (store.activeProfile.backlight ?? BacklightSettings()).isAnimated) { time in
                    // While Hypershift is physically held, show what each key does in that layer.
                    DeviceView(
                        profile: store.activeProfile,
                        layer: model.isHypershiftHeld ? .hypershift : layer,
                        pressedKeyIDs: model.livePressedKeyIDs,
                        activeSideLight: model.activeProfileIndex,
                        scale: scale,
                        time: time,
                        lastPressTimes: model.lastPressTimes,
                        selectedKeyID: $selectedKeyID
                    ) { key in
                        KeyPopoverView(key: key, layer: layer, profile: $store.activeProfile)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}

/// How much to scale the 445 × 665 drawing so it fits the space, within sensible limits.
func fitScale(for size: CGSize) -> CGFloat {
    let scale = min(size.width / PadGeometry.size.width, size.height / PadGeometry.size.height)
    return min(max(scale, 0.6), 1.35)
}

/// Re-runs its content ~30 times a second with the current time while `isAnimated` is true,
/// so animated lighting effects play on the drawing. Paused (no wasted work) otherwise.
struct LiveClock<Content: View>: View {
    let isAnimated: Bool
    @ViewBuilder let content: (Double) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isAnimated)) { context in
            content(context.date.timeIntervalSinceReferenceDate)
        }
    }
}

/// The popover that opens next to a clicked key.
struct KeyPopoverView: View {
    let key: PhysicalKey
    let layer: Layer
    @Binding var profile: Profile

    @State private var isRecording = false
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Key \(key.label)")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("Default \(key.defaultName)")
                    .foregroundStyle(Theme.textMuted)
            }

            if key.id == profile.hypershiftKeyID {
                Text("This is your Hypershift key. Hold it to use the Hypershift layer.")
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Stop Using as Hypershift") { profile.hypershiftKeyID = nil }
                    .buttonStyle(PillButtonStyle())
            } else {
                Text(isRecording ? "Press a key or shortcut…" : currentMappingText)
                    .font(.system(size: isRecording ? 14 : 22, weight: .bold))
                    .foregroundStyle(isRecording ? Theme.river : Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isRecording ? Theme.river : Theme.border))

                Button(isRecording ? "Cancel" : "Record New Key") {
                    isRecording ? stopRecording() : startRecording()
                }
                .buttonStyle(PillButtonStyle(prominent: !isRecording))
                .help("Then press the key or shortcut this Tartarus key should type")

                HStack(spacing: 8) {
                    Button("Next Profile") { profile.setAction(.nextProfile, for: key.id, in: layer) }
                        .buttonStyle(PillButtonStyle())
                        .help("Make this key switch to the next profile")
                    Button("Reset") { profile.setAction(nil, for: key.id, in: layer) }
                        .buttonStyle(PillButtonStyle())
                        .disabled(profile.action(for: key.id, in: layer) == nil)
                }

                if layer == .normal {
                    Button("Use as Hypershift Key") { profile.hypershiftKeyID = key.id }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .help("Holding this key will switch every other key to its Hypershift mapping")
                }
            }
        }
        .padding(16)
        .frame(width: 270)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onDisappear { stopRecording() }
    }

    private var currentMappingText: String {
        if let action = profile.action(for: key.id, in: layer) { return action.displayName }
        if layer == .hypershift { return "Same as Normal" }
        return key.defaultName
    }

    /// Starts listening for the next key press and saves it as the mapping.
    /// Uses an NSEvent "local monitor": a hook that sees key events before the app handles
    /// them, so even shortcuts like ⌘Q get recorded instead of quitting the app.
    private func startRecording() {
        isRecording = true
        var pendingModifierKeyCode: UInt16?   // a modifier key that's down with nothing else yet

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                // A normal key, possibly with modifiers held → a key or a shortcut.
                save(KeyAction(keyCode: event.keyCode, modifiers: Modifiers(event.modifierFlags)))
            } else {
                // A modifier key went down or up. If one is pressed and released on its own,
                // the user wants the Tartarus key to *be* that modifier (e.g. Shift).
                let anyModifierDown = !event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
                if anyModifierDown {
                    pendingModifierKeyCode = event.keyCode
                } else if let code = pendingModifierKeyCode {
                    save(KeyAction(keyCode: code))
                }
            }
            return nil   // swallow the event so it doesn't trigger anything in the app
        }
    }

    private func save(_ action: KeyAction) {
        profile.setAction(action, for: key.id, in: layer)
        stopRecording()
    }

    private func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        isRecording = false
    }
}

// MARK: - Lighting

struct LightingScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var store = model.store
        let settings = store.activeProfile.backlight ?? BacklightSettings()

        HStack(spacing: 48) {
            GeometryReader { geometry in
                LiveClock(isAnimated: settings.isAnimated) { time in
                    DeviceView(
                        profile: store.activeProfile,
                        layer: .normal,
                        pressedKeyIDs: model.livePressedKeyIDs,
                        activeSideLight: model.activeProfileIndex,
                        scale: fitScale(for: geometry.size),
                        time: time,
                        lastPressTimes: model.lastPressTimes,
                        selectedKeyID: .constant(nil)
                    ) { _ in EmptyView() }
                    .allowsHitTesting(false)   // keys aren't clickable on this screen
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            LightingEditorView(
                profileTitle: "Profile \(romanNumeral((model.activeProfileIndex ?? 0) + 1)) · \(store.activeProfile.name)",
                settings: Binding(get: { settings }, set: { store.activeProfile.backlight = $0 })
            )
            .frame(width: 360)
        }
        .padding(24)
    }
}

// The editor window: pick a profile, see a picture of the Tartarus with each key's current
// mapping, click a key, then press the key or shortcut you want it to type.

import SwiftUI

struct EditorView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedKeyID: String?
    @State private var layer: Layer = .normal
    // The name box only appears while renaming, so it can't grab key presses when the window opens.
    @State private var isRenaming = false

    var body: some View {
        @Bindable var store = model.store

        VStack(alignment: .leading, spacing: 16) {
            // Profile controls
            HStack {
                Picker("Profile", selection: $store.activeProfileID) {
                    ForEach(store.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .frame(width: 220)
                if isRenaming {
                    TextField("Name", text: $store.activeProfile.name)
                        .frame(width: 150)
                        .onSubmit { isRenaming = false }   // pressing Return finishes renaming
                    Button("Done") { isRenaming = false }
                } else {
                    Button("Rename") { isRenaming = true }
                }
                Button("New Profile") { store.addProfile() }
                    .disabled(store.profiles.count >= ProfileStore.maxProfiles)
                    .help("Up to \(ProfileStore.maxProfiles) profiles — one for each side light")
                Button("Delete Profile") { store.deleteActiveProfile() }
                    .disabled(store.profiles.count < 2)
            }

            // Layer + Hypershift key
            HStack {
                Picker("Layer", selection: $layer) {
                    ForEach(Layer.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                if model.isHypershiftHeld {
                    Text("HYPERSHIFT ACTIVE")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange))
                        .foregroundStyle(.white)
                }
                Spacer()
                Picker("Hypershift key", selection: $store.activeProfile.hypershiftKeyID) {
                    Text("None").tag(String?.none)
                    ForEach(TartarusLayout.allKeys) { key in
                        Text("\(key.label) (\(key.defaultName))").tag(Optional(key.id))
                    }
                }
                .frame(width: 240)
            }

            // While Hypershift is physically held, show what each key does in that layer.
            TartarusPictureView(
                profile: store.activeProfile,
                layer: model.isHypershiftHeld ? .hypershift : layer,
                selectedKeyID: $selectedKeyID,
                livePressedKeyIDs: model.livePressedKeyIDs
            )

            Divider()

            if let keyID = selectedKeyID, let key = TartarusLayout.key(withID: keyID) {
                KeyDetailView(key: key, layer: layer, profile: $store.activeProfile)
                    .id("\(keyID)-\(layer)")   // reset recording state when the selection changes
            } else {
                Text("Click a key above to change what it does.")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Text(model.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 720, height: 560)
    }
}

/// Draws the Tartarus: the 4 main rows on the left, the thumb area on the right.
struct TartarusPictureView: View {
    let profile: Profile
    let layer: Layer
    @Binding var selectedKeyID: String?
    let livePressedKeyIDs: Set<String>

    var body: some View {
        HStack(alignment: .bottom, spacing: 40) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(TartarusLayout.mainRows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(TartarusLayout.mainRows[rowIndex]) { key in keyCap(key) }
                    }
                }
            }
            VStack(spacing: 8) {
                keyCap(TartarusLayout.sideButton)
                keyCap(TartarusLayout.dpadUp)
                HStack(spacing: 8) {
                    keyCap(TartarusLayout.dpadLeft)
                    keyCap(TartarusLayout.dpadRight)
                }
                keyCap(TartarusLayout.dpadDown)
                keyCap(TartarusLayout.thumbKey, width: 148)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.08)))
    }

    private func keyCap(_ key: PhysicalKey, width: CGFloat = 70) -> some View {
        let isHypershiftKey = key.id == profile.hypershiftKeyID
        let customAction = profile.action(for: key.id, in: layer)

        // What to print on the key cap.
        let mappingText: String
        if isHypershiftKey {
            mappingText = "Hypershift"
        } else if let customAction {
            mappingText = customAction.displayName
        } else if layer == .hypershift, let normalAction = profile.action(for: key.id, in: .normal) {
            mappingText = normalAction.displayName   // falls back to the normal layer
        } else {
            mappingText = key.defaultName
        }

        return KeyCapView(
            label: key.label,
            mappingText: mappingText,
            isCustom: customAction != nil || isHypershiftKey,
            isSelected: key.id == selectedKeyID,
            isLivePressed: livePressedKeyIDs.contains(key.id),
            width: width
        )
        .onTapGesture { selectedKeyID = key.id }
    }
}

/// One key on the picture.
struct KeyCapView: View {
    let label: String
    let mappingText: String
    let isCustom: Bool        // has a mapping in this layer → shown highlighted
    let isSelected: Bool
    let isLivePressed: Bool   // physically held down on the Tartarus right now
    let width: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(mappingText)
                .font(.system(size: 13, weight: isCustom ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 4)
        .frame(width: width, height: 56)
        .background(RoundedRectangle(cornerRadius: 8).fill(fillColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2.5 : 1)
        )
        .contentShape(Rectangle())   // make the whole key clickable, not just the text
    }

    private var fillColor: Color {
        if isLivePressed { return .green.opacity(0.45) }
        if isCustom { return .accentColor.opacity(0.18) }
        return Color(nsColor: .controlBackgroundColor)
    }
}

/// The panel under the picture for editing the selected key.
struct KeyDetailView: View {
    let key: PhysicalKey
    let layer: Layer
    @Binding var profile: Profile

    @State private var isRecording = false
    @State private var keyMonitor: Any?

    var body: some View {
        if key.id == profile.hypershiftKeyID {
            Text("Key \(key.label) is this profile's Hypershift key. Hold it to use the Hypershift layer.")
        } else {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key \(key.label) — \(layer.rawValue) layer").font(.headline)
                    Text("Default: \(key.defaultName)").foregroundStyle(.secondary)
                }
                Spacer()
                Text(currentMappingText)
                    .font(.title3.monospaced())
                if isRecording {
                    Text("Press a key or shortcut…").foregroundStyle(Color.accentColor)
                    Button("Cancel") { stopRecording() }
                } else {
                    Button("Record New Key") { startRecording() }
                    Button("Next Profile") { profile.setAction(.nextProfile, for: key.id, in: layer) }
                        .help("Make this key switch to the next profile")
                    Button("Reset") { profile.setAction(nil, for: key.id, in: layer) }
                        .disabled(profile.action(for: key.id, in: layer) == nil)
                }
            }
            .onDisappear { stopRecording() }
        }
    }

    private var currentMappingText: String {
        if let action = profile.action(for: key.id, in: layer) { return action.displayName }
        if layer == .hypershift { return "(same as Normal)" }
        return key.defaultName
    }

    /// Starts listening for the next key press in this window and saves it as the mapping.
    /// Uses an NSEvent "local monitor": a hook that sees key events before the window handles
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

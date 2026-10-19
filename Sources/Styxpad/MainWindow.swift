// The main window, built around a drawing of the Tartarus:
// - the title bar holds the STYXPAD wordmark, the profile switcher (I · II · III),
//   the Keys / Lighting / Macros switch and a connection dot;
// - Keys: click a key on the drawing and a popover next to it lets you change it;
// - Lighting: the profile's backlight effect, colors and brightness, previewed on the drawing;
// - Macros: the macro library (MacrosScreen.swift).

import SwiftUI
import UniformTypeIdentifiers   // for UTType, the "kind of file" type the file picker filters by

enum EditorTab: String, CaseIterable {
    case keys = "Keys"
    case lighting = "Lighting"
    case macros = "Macros"
}

struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: EditorTab = .keys
    // "@AppStorage" = a setting saved in the app's preferences that SwiftUI also watches.
    @AppStorage(WelcomeView.completedKey) private var hasCompletedWelcome = false

    var body: some View {
        VStack(spacing: 0) {
            RiverLine()
            if !hasCompletedWelcome {
                WelcomeView { hasCompletedWelcome = true }
            } else {
                if !model.isConnected {
                    ConnectionBanner()
                }
                if let copy = model.unreadableProfilesCopy {
                    UnreadableProfilesBanner(copy: copy)
                }
                if let update = model.updates.availableUpdate, !model.updates.isBannerDismissed {
                    UpdateBanner(update: update)
                }
                switch tab {
                case .keys: KeysScreen()
                case .lighting: LightingScreen()
                case .macros: MacrosScreen()
                }
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
            if hasCompletedWelcome {
                ToolbarItem(placement: .principal) {
                    ProfileSwitcher()
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 14) {
                        PillPicker(options: EditorTab.allCases.map { ($0.rawValue, $0) }, selection: $tab)
                        ConnectionDot()
                        SettingsLink {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Settings")
                    }
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

/// The profile dropdown: a pill showing the active profile. Clicking it lists all profiles
/// (with their side-light patterns) to switch between, and adds, imports, renames, exports
/// or deletes profiles.
struct ProfileSwitcher: View {
    @Environment(AppModel.self) private var model
    @State private var renamingProfileID: UUID?
    @State private var renameText = ""
    @State private var showImportError = false

    var body: some View {
        @Bindable var store = model.store
        let active = store.activeProfile
        let activeIndex = model.activeProfileIndex ?? 0
        let activeName = active.name.isEmpty ? "Untitled" : active.name
        let isFull = store.profiles.count >= ProfileStore.maxProfiles

        Menu {
            // An inline Picker inside a menu shows as a plain list of items with a ✓ on the chosen one.
            Picker("Profile", selection: $store.activeProfileID) {
                ForEach(Array(store.profiles.enumerated()), id: \.element.id) { index, profile in
                    Label {
                        Text("\(romanNumeral(index + 1))   \(profile.name.isEmpty ? "Untitled" : profile.name)")
                    } icon: {
                        lightDotsImage(index)
                    }
                    .tag(profile.id)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("New Profile") { store.addProfile() }
                .disabled(isFull)
            Button("Import Profile…") { importProfile() }
                .disabled(isFull)
            Divider()
            Button("Rename “\(activeName)”…") {
                renameText = active.name
                renamingProfileID = active.id
            }
            Button("Export “\(activeName)”…") { export(active) }
            Menu("Print Shortcut Sheet") {
                ForEach(Layer.allCases) { layer in
                    Button("\(layer.rawValue) Shortcuts…") {
                        ShortcutSheet.printProfile(active, layer: layer, macros: store.macros)
                    }
                }
                Divider()
                Button("Blank Worksheet…") {
                    ShortcutSheet.printProfile(active, layer: .normal, macros: [], blank: true)
                }
            }
            Button("Delete “\(activeName)”", role: .destructive) { store.deleteProfile(active.id) }
                .disabled(store.profiles.count < 2)
        } label: {
            HStack(spacing: 7) {
                Text(romanNumeral(activeIndex + 1))
                    .font(Theme.display(13))
                Text(activeName)
                    .font(.system(size: 13, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.riverInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.river))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(3)
        .background(Capsule().fill(Theme.raised))
        .overlay(Capsule().strokeBorder(Theme.border))
        .help("Profile \(romanNumeral(activeIndex + 1)) — side lights \(lightDots(activeIndex)) (top to bottom). "
            + "Click to switch, add or import profiles (up to \(ProfileStore.maxProfiles)), or to rename, export or delete this one.")
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
        .alert("Couldn't import that file", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("It isn't a profile exported from Styxpad or Razer Synapse.")
        }
    }

    /// A profile's side-light pattern as dots, top light first: "●○○" for profile I.
    private func lightDots(_ index: Int) -> String {
        let patterns = TartarusLayout.profileLightPatterns
        return patterns[index % patterns.count].map { $0 ? "●" : "○" }.joined()
    }

    /// The same pattern as a small picture for the menu: lit lights as dots in their own color,
    /// unlit ones as grey rings. (Menus can't color text, but they do show pictures in color.)
    private func lightDotsImage(_ index: Int) -> Image {
        let patterns = TartarusLayout.profileLightPatterns
        let pattern = patterns[index % patterns.count]
        let dotSize: CGFloat = 9, gap: CGFloat = 3
        let size = NSSize(width: dotSize * 3 + gap * 2, height: dotSize)
        // This NSImage initializer draws with the code in { } whenever the picture is shown.
        let image = NSImage(size: size, flipped: false) { _ in
            for (light, isLit) in pattern.enumerated() {
                let dot = NSRect(x: CGFloat(light) * (dotSize + gap), y: 0, width: dotSize, height: dotSize)
                if isLit {
                    NSColor(Theme.sideLightColors[light]).setFill()
                    NSBezierPath(ovalIn: dot).fill()
                } else {
                    NSColor.tertiaryLabelColor.setStroke()
                    let ring = NSBezierPath(ovalIn: dot.insetBy(dx: 0.75, dy: 0.75))
                    ring.lineWidth = 1.5
                    ring.stroke()
                }
            }
            return true
        }
        return Image(nsImage: image).renderingMode(.original)   // .original = keep its colors
    }

    /// Saves one profile (plus the macros it uses) to a file you choose.
    private func export(_ profile: Profile) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(profile.name) (Styxpad profile).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.store.exportData(forProfile: profile.id).write(to: url)
        } catch {
            print("Styxpad: couldn't export profile: \(error)")
        }
    }

    /// Lets you pick an exported profile file (from Styxpad, or Razer Synapse on Windows) and adds it.
    private func importProfile() {
        let panel = NSOpenPanel()
        // compactMap drops the nil in case macOS can't make a type for ".synapse4".
        panel.allowedContentTypes = [.json] + [UTType(filenameExtension: "synapse4")].compactMap { $0 }
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if url.pathExtension == "synapse4" {
                try importFromSynapse(Data(contentsOf: url))
            } else {
                try model.store.importProfile(from: Data(contentsOf: url))
            }
        } catch {
            showImportError = true
        }
    }

    /// Shows what a Razer Synapse file will turn into and what gets skipped, with a
    /// "Turn Ctrl into ⌘" checkbox, then imports it if you click Import.
    private func importFromSynapse(_ data: Data) throws {
        let preview = try SynapseImport.convert(data, ctrlToCommand: true)
        let room = ProfileStore.maxProfiles - model.store.profiles.count
        let count = min(preview.profiles.count, room)
        var notes = preview.notes
        if preview.profiles.count > room {
            let leftOut = preview.profiles.dropFirst(room).map { "“\($0.name)”" }.joined(separator: ", ")
            notes.insert("Styxpad holds \(ProfileStore.maxProfiles) profiles, so \(leftOut) didn't fit.", at: 0)
        }

        let alert = NSAlert()
        alert.messageText = "Import from Razer Synapse"
        alert.informativeText = "Adds \(count == 1 ? "1 profile" : "\(count) profiles"), one for each Synapse keymap. "
            + "Windows shortcuts use Ctrl where a Mac uses ⌘.\n\n"
            + notes.map { "• " + $0 }.joined(separator: "\n")
        let ctrlCheckbox = NSButton(checkboxWithTitle: "Turn Ctrl into ⌘", target: nil, action: nil)
        ctrlCheckbox.state = .on
        alert.accessoryView = ctrlCheckbox
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // Convert again with the checkbox's choice (the preview above assumed it was on).
        let result = try SynapseImport.convert(data, ctrlToCommand: ctrlCheckbox.state == .on)
        model.store.importFromSynapse(profiles: Array(result.profiles.prefix(room)), macros: result.macros)
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

/// Shown when the saved profiles couldn't be read at launch (e.g. after going back to an older
/// Styxpad): Styxpad started fresh, and this says where the old file was kept.
struct UnreadableProfilesBanner: View {
    @Environment(AppModel.self) private var model
    let copy: URL

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Styxpad couldn't read your saved profiles, so it started fresh. The old file was kept as “\(copy.lastPathComponent)”.")
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([copy]) }
            Button("Dismiss") { model.unreadableProfilesCopy = nil }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Theme.panel)
    }
}

/// "Styxpad 0.3 is available. [Download] [Later]": shown when GitHub has a newer release.
struct UpdateBanner: View {
    @Environment(AppModel.self) private var model
    let update: UpdateChecker.Release

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(Theme.river)
            Text("Styxpad \(update.version) is available. You have \(model.updates.currentVersion).")
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Button("Download") { NSWorkspace.shared.open(update.pageURL) }
            Button("Later") { model.updates.isBannerDismissed = true }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Theme.panel)
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
            LinkedAppsBar()

            GeometryReader { geometry in
                let scale = fitScale(for: geometry.size)
                LiveClock(isAnimated: (store.activeProfile.backlight ?? BacklightSettings()).isAnimated) { time in
                    // While Hypershift is physically held, show what each key does in that layer.
                    DeviceView(
                        profile: store.activeProfile,
                        layer: model.isHypershiftHeld ? .hypershift : layer,
                        pressedKeyIDs: model.livePressedKeyIDs,
                        activeProfileIndex: model.activeProfileIndex,
                        scale: scale,
                        time: time,
                        lastPressTimes: model.lastPressTimes,
                        macros: store.macros,
                        selectedKeyID: $selectedKeyID
                    ) { key in
                        KeyPopoverView(key: key, layer: layer, profile: $store.activeProfile, macros: store.macros)
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

/// "Switches on for: Photoshop ✕  + Add App": the apps that make the active profile switch on
/// when they come to the front (see AppProfileLinker).
struct LinkedAppsBar: View {
    @Environment(AppModel.self) private var model
    /// The apps open right now, offered first in the + Add App menu. Kept up to date as apps open and quit.
    @State private var openApps: [NSRunningApplication] = []

    var body: some View {
        let store = model.store
        let profile = store.activeProfile

        HStack(spacing: 8) {
            Text("Switches on for:")
                .foregroundStyle(Theme.textMuted)
            ForEach(profile.linkedAppIDs ?? [], id: \.self) { bundleID in
                HStack(spacing: 6) {
                    if let url = appURL(bundleID) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text(appName(bundleID))
                    Button { store.unlinkApp(bundleID) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Stop switching to this profile for \(appName(bundleID))")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.raised))
                .overlay(Capsule().strokeBorder(Theme.border))
            }
            Menu {
                // Picking an open app gets its exact ID, even for a Windows app in Parallels
                // whose stand-in apps share one name.
                Section("Open Apps") {
                    ForEach(openApps, id: \.processIdentifier) { app in
                        let bundleID = app.bundleIdentifier ?? ""
                        let isLinked = profile.linkedAppIDs?.contains(bundleID) == true
                        // A Toggle in a menu shows a ✓ when on. Apps already linked here show the ✓
                        // and are greyed out; picking any other app links it.
                        Toggle(isOn: Binding(get: { isLinked },
                                             set: { _ in store.linkApp(bundleID, toProfile: profile.id) })) {
                            Label { Text(app.localizedName ?? bundleID) } icon: { menuIcon(app.icon) }
                        }
                        .disabled(isLinked)
                    }
                }
                Divider()
                Button("Choose from Applications…") { chooseApp(for: profile.id) }
            } label: {
                Text("+ Add App").foregroundStyle(Theme.river)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Pick an app; whenever it's in front, Styxpad switches to this profile")
            Spacer()
        }
        .font(.system(size: 12))
        .onAppear { refreshOpenApps() }
        // macOS announces whenever an app opens or quits; refresh the list then.
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            refreshOpenApps()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            refreshOpenApps()
        }
    }

    /// Fills openApps: apps with a Dock icon ("regular" apps, so no background helpers), sorted by
    /// name, minus the ones that never switch profiles (Parallels' own app).
    private func refreshOpenApps() {
        openApps = NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular, let bundleID = app.bundleIdentifier else { return false }
                return !AppProfileLinker.ignoredAppIDs.contains(bundleID)
            }
            .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }
    }

    /// An app's icon at menu size. App icons come in big sizes, and a menu shows a picture at its own size.
    private func menuIcon(_ icon: NSImage?) -> Image {
        let small = (icon?.copy() as? NSImage) ?? NSImage()   // a copy, so resizing doesn't change the app's icon elsewhere
        small.size = NSSize(width: 16, height: 16)
        return Image(nsImage: small)
    }

    private func appURL(_ bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    /// The app's name as Finder shows it, or its bundle ID if it's no longer installed.
    private func appName(_ bundleID: String) -> String {
        appURL(bundleID).map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID
    }

    private func chooseApp(for profileID: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        if panel.runModal() == .OK, let url = panel.url, let bundleID = Bundle(url: url)?.bundleIdentifier {
            model.store.linkApp(bundleID, toProfile: profileID)
        }
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
    let macros: [Macro]

    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var textEntry: TextEntry?   // set while the website/text box is showing
    @State private var enteredText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(key.defaultCommand == nil ? "Key \(key.label)" : key.label)   // wheel parts have their own name
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

                if let textEntry {
                    textEntryForm(textEntry)
                } else {
                    Button(isRecording ? "Cancel" : "Record New Key") {
                        isRecording ? stopRecording() : startRecording()
                    }
                    .buttonStyle(PillButtonStyle(prominent: !isRecording))
                    .help("Then press the key or shortcut this Tartarus key should type")

                    HStack(spacing: 8) {
                        moreActionsMenu
                        Button("Reset") { profile.setAction(nil, for: key.id, in: layer) }
                            .buttonStyle(PillButtonStyle())
                            .disabled(profile.action(for: key.id, in: layer) == nil)
                    }

                    // Wheel up/down ticks can't be held, so playing modes and Turbo don't apply.
                    if key.isInstant {
                        EmptyView()
                    } else if let action = effectiveAction, action.command == .runMacro {
                        option("Plays") {
                            PillPicker(options: MacroPlayback.allCases.map { ($0.name, $0) },
                                       selection: Binding(get: { action.playback ?? .once },
                                                          set: { playback in updateAction { $0.playback = playback } }))
                        }
                    } else if let action = effectiveAction, action.supportsTurbo {
                        option("Turbo") {
                            // 0 stands for "off" here; it's saved as nil.
                            PillPicker(options: [("Off", 0), ("5/s", 5), ("10/s", 10), ("20/s", 20)],
                                       selection: Binding(get: { action.turboRate ?? 0 },
                                                          set: { rate in updateAction { $0.turboRate = rate == 0 ? nil : rate } }))
                        }
                        .help("While the key is held, press it again and again this many times a second")
                    }
                }

                if layer == .normal && !key.isInstant {
                    Button("Use as Hypershift Key") { profile.hypershiftKeyID = key.id }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .help("Holding this key will switch every other key to its Hypershift mapping")
                }
            }
        }
        .padding(16)
        .frame(width: 290)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onDisappear { stopRecording() }
    }

    /// The menu of everything a key can do besides typing a key: mouse, media and other commands.
    private var moreActionsMenu: some View {
        Menu("More Actions") {
            Section("Mouse") {
                ForEach(Command.mouseCommands, id: \.self) { command in
                    Button(command.name) { setCommand(command) }
                }
            }
            Section("Media") {
                ForEach(Command.mediaCommands, id: \.self) { command in
                    Button(command.name) { setCommand(command) }
                }
            }
            Section("Macros") {
                Menu("Run Macro") {
                    ForEach(macros) { macro in
                        Button(macro.name) { setCommand(.runMacro, detail: macro.id.uuidString) }
                    }
                    if macros.isEmpty {
                        Text("No macros yet. Record one in the Macros tab.")
                    }
                }
            }
            Section("Other") {
                Button("Next Profile") { setCommand(.nextProfile) }
                Button("Disable Key") { setCommand(.disabled) }
                Button("Open App…") { chooseApp() }
                Button("Open Website…") { startTextEntry(.website) }
                Button("Type Text…") { startTextEntry(.text) }
            }
        }
        .menuStyle(.button)
        .buttonStyle(PillButtonStyle())
    }

    /// The two commands that need something typed in: a web address, or the text to type.
    enum TextEntry {
        case website, text
    }

    /// Replaces the buttons with a text box while you enter a web address or text.
    private func textEntryForm(_ entry: TextEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry == .website ? "Website address" : "Text to type")
                .foregroundStyle(Theme.textSecondary)
            TextField(entry == .website ? "example.com" : "gg wp", text: $enteredText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveTextEntry(entry) }   // pressing Return saves too
            HStack(spacing: 8) {
                Button("Cancel") { textEntry = nil }
                    .buttonStyle(PillButtonStyle())
                Button("Save") { saveTextEntry(entry) }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .disabled(enteredText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// A small label with a control below it (side by side, the choices don't fit the popover).
    private func option(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .foregroundStyle(Theme.textSecondary)
            control()
        }
    }

    /// What this key does right now in this layer: its own mapping, else (in the Hypershift layer)
    /// the Normal one, else the key it types out of the box — the same order the Remapper uses.
    private var effectiveAction: KeyAction? {
        profile.action(for: key.id, in: layer)
            ?? (layer == .hypershift ? profile.action(for: key.id, in: .normal) : nil)
            ?? defaultAction
    }

    private var defaultAction: KeyAction? { key.defaultAction }

    /// Changes one setting (playback, turbo) of this key's mapping and saves it.
    /// "inout" lets the `change` closure edit the action in place.
    private func updateAction(_ change: (inout KeyAction) -> Void) {
        guard var action = effectiveAction else { return }
        change(&action)
        // Back to exactly the out-of-the-box key (e.g. turbo switched off again) = no custom mapping.
        let isDefault = layer == .normal && action == defaultAction
        profile.setAction(isDefault ? nil : action, for: key.id, in: layer)
    }

    private func setCommand(_ command: Command, detail: String? = nil) {
        profile.setAction(KeyAction(keyCode: 0, command: command, detail: detail), for: key.id, in: layer)
    }

    /// Opens the text box, pre-filled with the current website or text if this key already has one.
    private func startTextEntry(_ entry: TextEntry) {
        let current = profile.action(for: key.id, in: layer)
        let matchingCommand: Command = entry == .website ? .openWebsite : .typeText
        enteredText = current?.command == matchingCommand ? (current?.detail ?? "") : ""
        textEntry = entry
    }

    private func saveTextEntry(_ entry: TextEntry) {
        var value = enteredText
        switch entry {
        case .text:
            guard !value.isEmpty else { return }
            setCommand(.typeText, detail: value)
        case .website:
            value = value.trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { return }
            // People usually type "youtube.com"; a browser needs the "https://" part to open it.
            if !value.contains("://") { value = "https://" + value }
            setCommand(.openWebsite, detail: value)
        }
        textEntry = nil
    }

    /// Shows the standard "choose a file" window, limited to apps, starting in Applications.
    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            setCommand(.openApp, detail: url.path)
        }
    }

    private var currentMappingText: String {
        if let action = profile.action(for: key.id, in: layer) { return action.displayName(macros: macros) }
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

    /// Custom effect: colors one key with the paint color (keys without a light are ignored).
    private func paint(_ keyID: String) {
        let store = model.store
        // Any of the wheel's three click zones paints the wheel's one light.
        let lightID = keyID.hasPrefix("wheel") ? TartarusLayout.wheelLightID : keyID
        guard TartarusLayout.lightOrder.contains(lightID), var settings = store.activeProfile.backlight else { return }
        settings.keyColors = (settings.keyColors ?? [:]).merging([lightID: settings.color1]) { _, new in new }
        store.activeProfile.backlight = settings
    }

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
                        activeProfileIndex: model.activeProfileIndex,
                        scale: fitScale(for: geometry.size),
                        time: time,
                        lastPressTimes: model.lastPressTimes,
                        macros: store.macros,
                        // Clicking a key "selects" it; here that paints it instead (and nothing stays selected).
                        selectedKeyID: Binding(get: { nil }, set: { keyID in if let keyID { paint(keyID) } })
                    ) { _ in EmptyView() }
                    .allowsHitTesting(settings.effect == .custom)   // keys are only clickable for painting
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

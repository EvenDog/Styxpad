// The data the user edits: what each Tartarus key should do, grouped into named profiles,
// plus ProfileStore, which keeps the list of profiles and saves it to disk as JSON
// (~/Library/Application Support/Styxpad/profiles.json).

import AppKit
import Observation

/// Modifier keys that can be part of a shortcut (e.g. the ⌘ and ⇧ in ⌘⇧4).
/// "OptionSet" is Swift's way to store a set of on/off flags in one number.
struct Modifiers: OptionSet, Codable, Hashable {
    let rawValue: Int
    static let control = Modifiers(rawValue: 1 << 0)
    static let option = Modifiers(rawValue: 1 << 1)
    static let shift = Modifiers(rawValue: 1 << 2)
    static let command = Modifiers(rawValue: 1 << 3)

    /// Builds our Modifiers from the modifier flags of a real key press in the editor window.
    init(_ flags: NSEvent.ModifierFlags) {
        var result: Modifiers = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        self = result
    }

    init(rawValue: Int) { self.rawValue = rawValue }

    /// The symbols macOS uses in menus, in Apple's standard order: ⌃⌥⇧⌘.
    var symbols: String {
        (contains(.control) ? "⌃" : "") + (contains(.option) ? "⌥" : "")
            + (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "")
    }

    /// The same modifiers in the format needed when sending a synthetic key event.
    var eventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.command) { flags.insert(.maskCommand) }
        return flags
    }
}

/// Special things a key can do instead of typing.
enum Command: String, Codable {
    case nextProfile   // switch to the next profile in the list
    case leftClick, rightClick, middleClick, scrollUp, scrollDown
    case playPause, nextTrack, previousTrack, volumeUp, volumeDown, mute
    case disabled      // the key does nothing at all
    case openApp, openWebsite, typeText   // these use KeyAction.detail
    case runMacro      // plays a macro from the library; KeyAction.detail holds its id

    /// The groups shown in the key popover's "More Actions" menu (the last three need extra input,
    /// so the menu lists them separately).
    static let mouseCommands: [Command] = [.leftClick, .rightClick, .middleClick, .scrollUp, .scrollDown]
    static let mediaCommands: [Command] = [.playPause, .nextTrack, .previousTrack, .volumeUp, .volumeDown, .mute]

    /// The name shown in the menu and on the key drawing.
    var name: String {
        switch self {
        case .nextProfile: "Next Profile"
        case .leftClick: "Left Click"
        case .rightClick: "Right Click"
        case .middleClick: "Middle Click"
        case .scrollUp: "Scroll Up"
        case .scrollDown: "Scroll Down"
        case .playPause: "Play/Pause"
        case .nextTrack: "Next Track"
        case .previousTrack: "Prev Track"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .mute: "Mute"
        case .disabled: "Disabled"
        case .openApp: "Open App"
        case .openWebsite: "Open Website"
        case .typeText: "Type Text"
        case .runMacro: "Run Macro"
        }
    }
}

/// What a Tartarus key should do: type one key, optionally with modifiers (a shortcut like ⌘C),
/// or — when `command` is set — run a command instead of typing anything.
struct KeyAction: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: Modifiers = []
    var command: Command? = nil   // optional, so profiles saved before commands existed still load
    /// Extra input for some commands: the app's file path (openApp), the web address (openWebsite)
    /// or the text to type (typeText), or the macro's id (runMacro). Optional for the same reason as `command`.
    var detail: String? = nil
    /// How a Run Macro key plays its macro (nil = once).
    var playback: MacroPlayback? = nil
    /// Turbo: while the key is held, it's pressed this many times a second (nil = turbo off).
    var turboRate: Int? = nil

    /// The "Next Profile" mapping. (keyCode is ignored when a command is set.)
    static let nextProfile = KeyAction(keyCode: 0, command: .nextProfile)

    /// Turbo only makes sense for things that can be pressed again and again.
    var supportsTurbo: Bool {
        switch command {
        case nil, .leftClick, .rightClick, .middleClick, .scrollUp, .scrollDown, .volumeUp, .volumeDown: true
        default: false
        }
    }

    /// The name shown on the key drawing and in the popover, with a ⚡ when turbo is on.
    /// Pass the macro library so a Run Macro key can show its macro's name.
    func displayName(macros: [Macro] = []) -> String {
        if command == .runMacro {
            return macros.first { $0.id.uuidString == detail }?.name ?? "No Macro"
        }
        return (turboRate != nil ? "⚡" : "") + baseName
    }

    private var baseName: String {
        guard let command else { return modifiers.symbols + KeyCodes.name(forMacKeyCode: keyCode) }
        switch command {
        case .openApp:
            // e.g. "/Applications/Safari.app" → "Safari" (Finder's name for it, without ".app").
            return detail.map { FileManager.default.displayName(atPath: $0) } ?? command.name
        case .openWebsite:
            return detail.flatMap { URL(string: $0)?.host() } ?? command.name   // just "youtube.com"
        case .typeText:
            return detail.map { "“\($0)”" } ?? command.name
        default:
            return command.name
        }
    }
}

/// The two layers: what keys do normally, and what they do while the Hypershift key is held.
enum Layer: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case hypershift = "Hypershift"
    var id: String { rawValue }
}

/// A named set of key mappings. Keys with no entry keep their default behavior.
struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var hypershiftKeyID: String?                 // which physical key acts as Hypershift (nil = none)
    var normalLayer: [String: KeyAction] = [:]   // physical key id → action
    var hypershiftLayer: [String: KeyAction] = [:]
    var backlight: BacklightSettings?            // optional only so profiles saved before lighting still load

    /// A fresh profile. The Side button starts out as "Next Profile", so you can always switch
    /// away from it (you can still remap Side in the editor).
    static func makeNew(named name: String) -> Profile {
        var profile = Profile(name: name, backlight: BacklightSettings())
        profile.normalLayer[TartarusLayout.sideButton.id] = .nextProfile
        return profile
    }

    func action(for keyID: String, in layer: Layer) -> KeyAction? {
        layer == .normal ? normalLayer[keyID] : hypershiftLayer[keyID]
    }

    /// Sets (or, when `action` is nil, removes) the mapping for one key in one layer.
    mutating func setAction(_ action: KeyAction?, for keyID: String, in layer: Layer) {
        switch layer {
        case .normal: normalLayer[keyID] = action
        case .hypershift: hypershiftLayer[keyID] = action
        }
    }
}

/// Holds all profiles and which one is active. Saves to disk automatically on every change.
/// "@Observable" lets SwiftUI views redraw automatically when these properties change.
@Observable
final class ProfileStore {
    var profiles: [Profile] { didSet { save(); onChange?() } }
    var activeProfileID: UUID { didSet { save(); onChange?() } }
    var macros: [Macro] = [] { didSet { save() } }

    /// Called after any change (switching profile, editing a mapping, ...).
    @ObservationIgnored var onChange: (() -> Void)?

    /// The format of the JSON file on disk.
    private struct SavedData: Codable {
        var profiles: [Profile]
        var activeProfileID: UUID
        var macros: [Macro]?   // optional, so files saved before macros existed still load
    }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "Styxpad/profiles.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode(SavedData.self, from: data),
           !saved.profiles.isEmpty {
            profiles = saved.profiles
            activeProfileID = saved.activeProfileID
            macros = saved.macros ?? []
        } else {
            let first = Profile.makeNew(named: "Default")
            profiles = [first]
            activeProfileID = first.id
        }

        // Profiles saved before lighting settings existed get the default backlight.
        for index in profiles.indices where profiles[index].backlight == nil {
            profiles[index].backlight = BacklightSettings()
        }
    }

    /// The profile currently in use. Setting it writes the edited copy back into `profiles`.
    var activeProfile: Profile {
        get { profiles.first { $0.id == activeProfileID } ?? profiles[0] }
        set {
            if let index = profiles.firstIndex(where: { $0.id == newValue.id }) {
                profiles[index] = newValue
            }
        }
    }

    /// One profile per side light on the Tartarus, so there can be at most 3.
    static let maxProfiles = 3

    func addProfile() {
        guard profiles.count < Self.maxProfiles else { return }
        let profile = Profile.makeNew(named: "Profile \(profiles.count + 1)")
        profiles.append(profile)
        activeProfileID = profile.id
    }

    /// Makes the next profile in the list active, wrapping around to the first after the last.
    func selectNextProfile() {
        guard let index = profiles.firstIndex(where: { $0.id == activeProfileID }) else { return }
        activeProfileID = profiles[(index + 1) % profiles.count].id   // % = remainder, so it wraps to 0
    }

    /// Deletes a profile (there must always be at least one left).
    func deleteProfile(_ id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        if activeProfileID == id { activeProfileID = profiles[0].id }
    }

    /// Adds an empty macro to the library and returns its id.
    func addMacro() -> UUID {
        let macro = Macro(name: "Macro \(macros.count + 1)")
        macros.append(macro)
        return macro.id
    }

    /// Deletes a macro, and resets every key (in every profile and layer) that was set to run it.
    func deleteMacro(_ id: UUID) {
        macros.removeAll { $0.id == id }
        let runsThisMacro = { (action: KeyAction) in action.command == .runMacro && action.detail == id.uuidString }
        for index in profiles.indices {
            profiles[index].normalLayer = profiles[index].normalLayer.filter { !runsThisMacro($0.value) }
            profiles[index].hypershiftLayer = profiles[index].hypershiftLayer.filter { !runsThisMacro($0.value) }
        }
    }

    private func save() {
        do {
            let folder = Self.fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(SavedData(profiles: profiles, activeProfileID: activeProfileID, macros: macros))
            try data.write(to: Self.fileURL)
        } catch {
            print("Styxpad: couldn't save profiles: \(error)")
        }
    }
}

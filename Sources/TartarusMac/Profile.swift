// The data the user edits: what each Tartarus key should do, grouped into named profiles,
// plus ProfileStore, which keeps the list of profiles and saves it to disk as JSON
// (~/Library/Application Support/TartarusMac/profiles.json).

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

/// What a Tartarus key should type: one key, optionally with modifiers (a shortcut like ⌘C).
struct KeyAction: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: Modifiers = []

    var displayName: String { modifiers.symbols + KeyCodes.name(forMacKeyCode: keyCode) }
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
    var profiles: [Profile] { didSet { save() } }
    var activeProfileID: UUID { didSet { save() } }

    /// The format of the JSON file on disk.
    private struct SavedData: Codable {
        var profiles: [Profile]
        var activeProfileID: UUID
    }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "TartarusMac/profiles.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode(SavedData.self, from: data),
           !saved.profiles.isEmpty {
            profiles = saved.profiles
            activeProfileID = saved.activeProfileID
        } else {
            let first = Profile(name: "Default")
            profiles = [first]
            activeProfileID = first.id
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

    func addProfile() {
        let profile = Profile(name: "Profile \(profiles.count + 1)")
        profiles.append(profile)
        activeProfileID = profile.id
    }

    func deleteActiveProfile() {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == activeProfileID }
        activeProfileID = profiles[0].id
    }

    private func save() {
        do {
            let folder = Self.fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(SavedData(profiles: profiles, activeProfileID: activeProfileID))
            try data.write(to: Self.fileURL)
        } catch {
            print("TartarusMac: couldn't save profiles: \(error)")
        }
    }
}

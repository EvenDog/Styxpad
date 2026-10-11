// Reads a profile file exported from Razer Synapse 4 on Windows (".synapse4") and turns it
// into Styxpad profiles and macros. Each Synapse "keymap" becomes its own Styxpad profile.
// Anything Styxpad can't bring over is collected in `notes`, so the import can say what was skipped.

import Foundation

enum SynapseImport {
    /// What a Synapse file turns into. Nothing is added to the app until the caller does so.
    struct Result {
        var profiles: [Profile] = []
        var macros: [Macro] = []
        var notes: [String] = []   // plain-English lines about what couldn't be imported
    }

    /// Converts a .synapse4 file's contents. Throws if it isn't a Synapse export.
    /// `ctrlToCommand` turns Windows' Ctrl into the Mac's ⌘ (Ctrl+Z → ⌘Z).
    static func convert(_ data: Data, ctrlToCommand: Bool) throws -> Result {
        let file = try JSONDecoder().decode(SynapseFile.self, from: data)
        var result = Result()

        // Macros. Synapse ids look like Styxpad's, so we keep them: re-importing then doesn't duplicate.
        for entry in file.macros ?? [] {
            let macro = try decodePayload(SynapseMacro.self, from: entry.payload)
            result.macros.append(Macro(id: UUID(uuidString: macro.guid) ?? UUID(), name: entry.name))
            result.notes.append("Macro “\(entry.name)” was added without its steps (Styxpad can't read Synapse recordings yet). Record it again under Macros.")
        }

        for entry in file.profiles {
            let synapseProfile = try decodePayload(SynapseProfile.self, from: entry.payload)
            // Keymaps in the order Synapse shows them (by slot number).
            let keymaps = synapseProfile.keymaps.sorted { (Int($0.slot ?? "") ?? 0) < (Int($1.slot ?? "") ?? 0) }
            for keymap in keymaps {
                // With several keymaps, "Keymap 1", "Keymap 2"… tell them apart better than the profile name.
                let name = keymaps.count > 1 ? keymap.name : entry.name
                var profile = Profile.makeNew(named: name)
                for mapping in keymap.mappings {
                    convert(mapping, into: &profile, macros: result.macros, ctrlToCommand: ctrlToCommand,
                            notes: &result.notes, where: name)
                }
                if !profile.hypershiftLayer.isEmpty {
                    result.notes.append("\(name): the file doesn't say which key is Hypershift. Pick one in the editor (“Use as Hypershift Key”).")
                }
                result.profiles.append(profile)
            }
        }
        result.notes.append("Lighting wasn't imported: Synapse exports don't include enough to copy it.")
        return result
    }

    /// Adds one Synapse mapping to `profile`, or a note when it can't be brought over.
    private static func convert(_ mapping: SynapseMapping, into profile: inout Profile, macros: [Macro],
                                ctrlToCommand: Bool, notes: inout [String], where profileName: String) {
        guard let key = physicalKey(forInputID: mapping.inputID) else {
            notes.append("\(profileName): skipped a mapping for “\(mapping.inputID)”, a key Styxpad doesn't know.")
            return
        }
        let layer: Layer = mapping.isHyperShift ? .hypershift : .normal
        let keyName = (key.defaultCommand == nil ? "Key \(key.label)" : key.label)
            + (layer == .hypershift ? " (Hypershift)" : "")
        func skip(_ why: String) { notes.append("\(profileName), \(keyName): \(why)") }
        let output = mapping.output

        switch output.outputType {
        case "keyboardGroup":
            guard let group = output.keyboardGroup, let keyNameInFile = group.key else { return }   // {} = not set
            guard var info = keyInfo(forSynapseName: keyNameInFile) else {
                return skip("types “\(keyNameInFile)”, which Styxpad doesn't know yet.")
            }
            if ctrlToCommand && info.name == "Control", let command = KeyCodes.all.first(where: { $0.name == "Command" }) {
                info = command   // a key that's just Ctrl (held for Ctrl-drag and so on) becomes ⌘ too
            }
            var modifiers: Modifiers = []
            for name in group.modifiers ?? [] {
                switch name {
                case "KEY_LEFT_CTRL": modifiers.insert(ctrlToCommand ? .command : .control)
                case "KEY_LEFT_SHIFT": modifiers.insert(.shift)
                case "KEY_LEFT_ALT": modifiers.insert(.option)
                default: return skip("uses the modifier “\(name)”, which Styxpad doesn't know yet.")
                }
            }
            profile.setAction(KeyAction(keyCode: info.macKeyCode, modifiers: modifiers), for: key.id, in: layer)

        case "disableGroup":
            profile.setAction(KeyAction(keyCode: 0, command: .disabled), for: key.id, in: layer)

        case "defaultGroup":
            profile.setAction(nil, for: key.id, in: layer)   // does what it does out of the box

        case "mouseGroup", "multimediaGroup":
            let name = output.mouseGroup?.mouseAssignment ?? output.multimediaGroup?.multimediaAssignment ?? ""
            guard let command = commandNames[name] else {
                return skip("“\(name)” isn't supported yet.")
            }
            var action = KeyAction(keyCode: 0, command: command)
            if output.multimediaGroup?.useTurbo == true {
                action.turboRate = 10   // Synapse doesn't save a rate here, so use Styxpad's middle setting
            }
            profile.setAction(action, for: key.id, in: layer)

        case "macroGroup":
            guard let group = output.macroGroup, let macro = macros.first(where: { $0.id.uuidString.lowercased() == group.guid?.lowercased() }) else {
                return skip("runs a macro that isn't in the file.")
            }
            let action = KeyAction(keyCode: 0, command: .runMacro, detail: macro.id.uuidString, playback: .once)
            if group.macroPlaybackOption != "Once" {
                skip("plays its macro “\(group.macroPlaybackOption ?? "")”, which isn't supported yet, so it plays once.")
            } else if let count = group.repeatCount, count > 1 {
                skip("played its macro \(count) times; Styxpad plays it once per press.")
            }
            profile.setAction(action, for: key.id, in: layer)

        case "keymapGroup" where output.keymapGroup?.type == "cycleDownKeymap" && output.keymapGroup?.isClutch != true:
            profile.setAction(.nextProfile, for: key.id, in: layer)   // keymaps became profiles, so "next keymap" = next profile

        default:
            skip("“\(output.outputType ?? "?")” isn't supported yet.")
        }
    }

    // MARK: Names used in Synapse files

    /// Synapse mouse and media actions we've seen in real exports, and the Styxpad command for each.
    /// Unknown ones end up in the notes; add them here once a file shows their name.
    private static let commandNames: [String: Command] = [
        "Click": .leftClick, "ScrollUp": .scrollUp, "ScrollDown": .scrollDown,
        "VolumeUp": .volumeUp, "VolumeDown": .volumeDown, "MuteAll": .mute,
    ]

    /// Synapse key names that differ from Styxpad's. Letters and digits match after "KEY_" ("KEY_Q" → "Q").
    private static let specialKeyNames: [String: String] = [
        "ESC": "Esc", "TAB": "Tab", "SPACEBAR": "Space", "CAPS_LOCK": "Caps Lock",
        "BACKSPACE": "Delete",    // Windows Backspace is the Mac's Delete…
        "DELETE": "Fwd Delete",   // …and Windows Delete is the Mac's Forward Delete
        "NUMPAD_ENTER": "Num Enter",
        "LEFT_SHIFT": "Shift", "LEFT_CTRL": "Control", "LEFT_ALT": "Option",
        "UP_ARROW": "↑", "DOWN_ARROW": "↓", "LEFT_ARROW": "←", "RIGHT_ARROW": "→",
    ]

    /// Looks up a Synapse key name like "KEY_TAB" in Styxpad's key table (nil if unknown).
    private static func keyInfo(forSynapseName synapseName: String) -> KeyInfo? {
        let shortName = synapseName.replacingOccurrences(of: "KEY_", with: "")
        let name = specialKeyNames[shortName] ?? shortName
        return KeyCodes.all.first { $0.name == name }
    }

    /// Which Tartarus key a Synapse input is. Synapse calls each key by what it types out of the box
    /// ("KEY_Q" is key 07), and the scroll wheel's parts by mouse names.
    private static func physicalKey(forInputID inputID: String) -> PhysicalKey? {
        switch inputID {
        case "ScrollUp": return TartarusLayout.wheelUp
        case "ScrollDown": return TartarusLayout.wheelDown
        default:
            guard let usage = keyInfo(forSynapseName: inputID)?.hidUsage else { return nil }
            return TartarusLayout.key(forHIDUsage: usage)
        }
    }

    /// Synapse wraps each profile and macro in base64 (a way of writing any data as plain letters
    /// and digits). This unwraps it and reads the JSON inside.
    private static func decodePayload<T: Decodable>(_ type: T.Type, from base64: String) throws -> T {
        guard let data = Data(base64Encoded: base64) else { throw CocoaError(.fileReadCorruptFile) }
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: The file format
// Only the parts we use are listed; JSONDecoder ignores the rest. Almost everything is optional
// ("?"), so a file that leaves something out still loads.

private struct SynapseFile: Decodable {
    struct Entry: Decodable {
        var name: String
        var payload: String
    }
    var profiles: [Entry]
    var macros: [Entry]?
}

private struct SynapseMacro: Decodable {
    var guid: String
}

private struct SynapseProfile: Decodable {
    var keymaps: [SynapseKeymap]
}

private struct SynapseKeymap: Decodable {
    var name: String
    var slot: String?
    var mappings: [SynapseMapping]
}

/// What one key does. Synapse writes it two ways: plain keys hold the output fields directly,
/// while analog keys (most of the Tartarus Pro) hold a "mapping" list whose first entry is the
/// action (the second is for a deeper press, which Styxpad doesn't have).
private struct SynapseMapping: Decodable {
    var inputID: String
    var isHyperShift: Bool
    var output: SynapseOutput

    private enum CodingKeys: String, CodingKey { case inputID, isHyperShift, mapping }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputID = try container.decode(String.self, forKey: .inputID)
        isHyperShift = try container.decodeIfPresent(Bool.self, forKey: .isHyperShift) ?? false
        // No "mapping" list → read the output fields from this same object.
        output = try container.decodeIfPresent([SynapseOutput].self, forKey: .mapping)?.first
            ?? SynapseOutput(from: decoder)
    }
}

private struct SynapseOutput: Decodable {
    struct KeyboardGroup: Decodable {
        var key: String?
        var modifiers: [String]?
    }
    struct MouseGroup: Decodable {
        var mouseAssignment: String?
    }
    struct MultimediaGroup: Decodable {
        var multimediaAssignment: String?
        var useTurbo: Bool?
    }
    struct MacroGroup: Decodable {
        var guid: String?
        var macroPlaybackOption: String?
        var repeatCount: Int?
    }
    struct KeymapGroup: Decodable {
        var type: String?
        var isClutch: Bool?
    }

    var outputType: String?
    var keyboardGroup: KeyboardGroup?
    var mouseGroup: MouseGroup?
    var multimediaGroup: MultimediaGroup?
    var macroGroup: MacroGroup?
    var keymapGroup: KeymapGroup?
}

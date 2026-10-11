// Macros: a recorded sequence of key presses and releases, with the pauses between them,
// that one Tartarus key can play back. Macros live in a library shared by all profiles;
// a key runs one with the "Run Macro" command (see KeyAction).

import Foundation

/// One step of a macro: wait `delay` milliseconds, then press (isDown) or release a key.
struct MacroStep: Codable, Equatable {
    var keyCode: UInt16   // Mac key code, as in KeyCodes
    var isDown: Bool
    var delay: Int        // milliseconds to wait before this step, as recorded
}

struct Macro: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var steps: [MacroStep] = []
    /// nil = wait the recorded time before each step; a number = wait this many milliseconds instead.
    var fixedDelay: Int? = nil

    /// How long to wait before step `index`. The first step plays right away.
    func delay(before index: Int) -> Int {
        index == 0 ? 0 : (fixedDelay ?? steps[index].delay)
    }

    /// The pause before a looping macro starts over: the fixed delay if set, otherwise 50 ms —
    /// never less than 10 ms, so an endless loop can't hog the Mac.
    var pauseBetweenRepeats: Int { max(fixedDelay ?? 50, 10) }
}

/// How a key plays its macro.
enum MacroPlayback: String, Codable, CaseIterable {
    case once        // each press plays it one time
    case whileHeld   // plays over and over while the key is held
    case toggle      // a press starts it looping, the next press stops it

    var name: String {
        switch self {
        case .once: "Once"
        case .whileHeld: "While Held"
        case .toggle: "Toggle"
        }
    }
}

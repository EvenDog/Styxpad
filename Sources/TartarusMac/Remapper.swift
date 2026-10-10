// The heart of the app: receives each Tartarus key press/release, decides what it should
// type according to the active profile (including the Hypershift layer), and types it
// by sending a synthetic key event to macOS (using CGEvent, part of Core Graphics).

import CoreGraphics

final class Remapper {
    private let store: ProfileStore
    private let eventSource = CGEventSource(stateID: .hidSystemState)

    /// The USB code of the Hypershift key while it's being held (nil when not held).
    private var heldHypershiftUsage: UInt32?

    /// What each currently-held Tartarus key typed when pressed. We remember this so the
    /// release always matches the press, even if you let go of Hypershift or switch
    /// profiles in between (otherwise a key could get "stuck" down).
    private var pressedActions: [UInt32: KeyAction] = [:]

    init(store: ProfileStore) {
        self.store = store
    }

    /// Handles one press (isDown = true) or release (false) of a Tartarus key.
    func handle(hidUsage: UInt32, isDown: Bool) {
        let profile = store.activeProfile
        let physicalKey = TartarusLayout.key(forHIDUsage: hidUsage)

        // The Hypershift key itself types nothing; it just switches layers while held.
        if !isDown && hidUsage == heldHypershiftUsage {
            heldHypershiftUsage = nil
            return
        }
        if isDown, let keyID = physicalKey?.id, keyID == profile.hypershiftKeyID {
            heldHypershiftUsage = hidUsage
            return
        }

        if isDown {
            guard pressedActions[hidUsage] == nil else { return }   // ignore duplicate "down" reports
            guard let action = action(for: hidUsage, physicalKey: physicalKey, in: profile) else { return }
            pressedActions[hidUsage] = action
            post(action, isDown: true)
        } else {
            guard let action = pressedActions.removeValue(forKey: hidUsage) else { return }
            post(action, isDown: false)
        }
    }

    /// Releases every key we're holding down. Used when the Tartarus is unplugged mid-press.
    func releaseAll() {
        let held = pressedActions.values
        pressedActions.removeAll()
        heldHypershiftUsage = nil
        for action in held { post(action, isDown: false) }
    }

    /// Picks what a key should do: Hypershift mapping (if held) → normal mapping → factory default.
    private func action(for hidUsage: UInt32, physicalKey: PhysicalKey?, in profile: Profile) -> KeyAction? {
        if let keyID = physicalKey?.id {
            if heldHypershiftUsage != nil, let action = profile.action(for: keyID, in: .hypershift) {
                return action
            }
            if let action = profile.action(for: keyID, in: .normal) {
                return action
            }
        }
        // No mapping: pass the key through as whatever it sends by default.
        return KeyCodes.macKeyCode(forHIDUsage: hidUsage).map { KeyAction(keyCode: $0) }
    }

    /// Types one key down or up, with the right modifier flags attached.
    private func post(_ action: KeyAction, isDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: action.keyCode, keyDown: isDown) else { return }

        // Modifier keys (Shift, Control, ...) are reported to macOS as a "flags changed"
        // event rather than a normal key down/up.
        if KeyCodes.modifierFlagForMacKeyCode[action.keyCode] != nil {
            event.type = .flagsChanged
        }
        event.flags = currentModifierFlags().union(action.modifiers.eventFlags)
        event.post(tap: .cghidEventTap)
    }

    /// Modifiers that should apply right now: those held on your main keyboard, plus any
    /// Tartarus keys mapped to a modifier (e.g. key 16 as Shift) that are currently held.
    private func currentModifierFlags() -> CGEventFlags {
        let relevant: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        var flags = CGEventSource.flagsState(.hidSystemState).intersection(relevant)
        for action in pressedActions.values {
            if let flag = KeyCodes.modifierFlagForMacKeyCode[action.keyCode] {
                flags.insert(flag)
            }
        }
        return flags
    }
}

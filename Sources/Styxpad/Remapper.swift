// The heart of the app: receives each Tartarus key press/release, decides what it should
// do according to the active profile (including the Hypershift layer), and does it: types a key
// by sending a synthetic key event to macOS (using CGEvent, part of Core Graphics), or runs a
// command such as a mouse click, a media key, opening an app or typing a piece of text.

import AppKit            // NSWorkspace (open apps/websites) and NSEvent (media keys)
import IOKit.hidsystem   // the NX_KEYTYPE_… media key numbers
import os

/// Debug messages for troubleshooting. Watch them live in Terminal with:
///   log stream --level debug --predicate 'subsystem == "com.danielschultz.Styxpad"'
/// Debug-level messages are only kept while someone is watching; they're never saved to disk.
private let log = Logger(subsystem: "com.danielschultz.Styxpad", category: "remapper")

final class Remapper {
    private let store: ProfileStore
    private let eventSource = CGEventSource(stateID: .hidSystemState)

    /// The USB code of the Hypershift key while it's being held (nil when not held).
    private var heldHypershiftUsage: UInt32?
    var isHypershiftHeld: Bool { heldHypershiftUsage != nil }

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
        log.debug("""
            \(isDown ? "DOWN" : "UP  ", privacy: .public) key \(physicalKey?.id ?? "?", privacy: .public) \
            (HID 0x\(String(hidUsage, radix: 16), privacy: .public)) — \
            hypershift held: \(self.heldHypershiftUsage != nil, privacy: .public), \
            hypershift key: \(profile.hypershiftKeyID ?? "none", privacy: .public)
            """)

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
            perform(action, isDown: true)
        } else {
            guard let action = pressedActions.removeValue(forKey: hidUsage) else { return }
            perform(action, isDown: false)
        }
    }

    /// Releases every key we're holding down. Used when the Tartarus is unplugged mid-press.
    func releaseAll() {
        let held = pressedActions.values
        pressedActions.removeAll()
        heldHypershiftUsage = nil
        for action in held { perform(action, isDown: false) }
    }

    /// Carries out one press or release of a mapping: types a key, or runs its command.
    /// Things that only need to happen once (switching profile, opening an app, ...) happen on the press.
    private func perform(_ action: KeyAction, isDown: Bool) {
        guard let command = action.command else { return post(action, isDown: isDown) }
        log.debug("  → \(command.rawValue, privacy: .public) \(isDown ? "down" : "up", privacy: .public)")

        switch command {
        // Pressed and released along with the Tartarus key (so holding Left Click lets you drag).
        case .leftClick: postMouseButton(.left, isDown: isDown)
        case .rightClick: postMouseButton(.right, isDown: isDown)
        case .middleClick: postMouseButton(.center, isDown: isDown)
        case .playPause: postMediaKey(NX_KEYTYPE_PLAY, isDown: isDown)
        case .nextTrack: postMediaKey(NX_KEYTYPE_NEXT, isDown: isDown)
        case .previousTrack: postMediaKey(NX_KEYTYPE_PREVIOUS, isDown: isDown)
        case .volumeUp: postMediaKey(NX_KEYTYPE_SOUND_UP, isDown: isDown)
        case .volumeDown: postMediaKey(NX_KEYTYPE_SOUND_DOWN, isDown: isDown)
        case .mute: postMediaKey(NX_KEYTYPE_MUTE, isDown: isDown)
        // Happen once, on the press.
        case .nextProfile: if isDown { store.selectNextProfile() }
        case .scrollUp: if isDown { postScroll(lines: Self.linesPerScroll) }
        case .scrollDown: if isDown { postScroll(lines: -Self.linesPerScroll) }
        case .openApp:
            if isDown, let path = action.detail { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
        case .openWebsite:
            if isDown, let address = action.detail, let url = URL(string: address) { NSWorkspace.shared.open(url) }
        case .typeText:
            if isDown, let text = action.detail { type(text) }
        case .disabled: break
        }
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
        log.debug("  → typing \(action.displayName, privacy: .public) \(isDown ? "down" : "up", privacy: .public)")
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: action.keyCode, keyDown: isDown) else { return }

        // Modifier keys (Shift, Control, ...) are reported to macOS as a "flags changed"
        // event rather than a normal key down/up.
        if KeyCodes.modifierFlagForMacKeyCode[action.keyCode] != nil {
            event.type = .flagsChanged
        }
        event.flags = currentModifierFlags().union(action.modifiers.eventFlags)
        event.post(tap: .cghidEventTap)
    }

    // MARK: Mouse, media and text

    /// How far one press of Scroll Up/Down scrolls, in lines.
    private static let linesPerScroll: Int32 = 3

    /// The last click, so two quick clicks of the same button count as a double-click.
    private var lastClick: (button: CGMouseButton, time: TimeInterval, count: Int64)?

    /// Presses or releases a mouse button wherever the pointer is. Your modifier keys apply,
    /// so ⌘ + a Tartarus "Left Click" is a ⌘-click.
    private func postMouseButton(_ button: CGMouseButton, isDown: Bool) {
        let pointerLocation = CGEvent(source: nil)?.location ?? .zero   // an empty event reports where the pointer is
        let type: CGEventType = switch button {
        case .left: isDown ? .leftMouseDown : .leftMouseUp
        case .right: isDown ? .rightMouseDown : .rightMouseUp
        default: isDown ? .otherMouseDown : .otherMouseUp
        }

        // Apps tell single from double clicks by a "click count" on each event. Real mice get it
        // from macOS; for our own clicks we count: same button again within the double-click time → +1.
        let now = ProcessInfo.processInfo.systemUptime
        if isDown {
            if let last = lastClick, last.button == button, now - last.time < NSEvent.doubleClickInterval {
                lastClick = (button, now, last.count + 1)
            } else {
                lastClick = (button, now, 1)
            }
        }

        guard let event = CGEvent(mouseEventSource: eventSource, mouseType: type,
                                  mouseCursorPosition: pointerLocation, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: lastClick?.count ?? 1)
        event.flags = currentModifierFlags()
        event.post(tap: .cghidEventTap)
    }

    /// Scrolls like a mouse wheel: positive lines scroll up, negative scroll down.
    private func postScroll(lines: Int32) {
        guard let event = CGEvent(scrollWheelEvent2Source: eventSource, units: .line,
                                  wheelCount: 1, wheel1: lines, wheel2: 0, wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }

    /// Presses or releases a media key (volume, play/pause, ...), exactly as the keys on a Mac keyboard do.
    /// These aren't ordinary key events: macOS sends them as a "system-defined" event (subtype 8)
    /// whose data packs the key type and down/up state into one number. Apple doesn't document this
    /// format, but it has been stable for many years and other Mac remapping apps rely on it too.
    private func postMediaKey(_ keyType: Int32, isDown: Bool) {
        let state = isDown ? 0xA00 : 0xB00   // 0xA = key down, 0xB = key up
        let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state)),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: (Int(keyType) << 16) | state, data2: -1)
        event?.cgEvent?.post(tap: .cghidEventTap)
    }

    /// Types a piece of text, one character at a time. Each key event carries the character itself
    /// instead of a key code, so any text works, including emoji and accented letters.
    private func type(_ text: String) {
        for character in text {
            let utf16 = Array(String(character).utf16)   // the character in the format CGEvent expects
            for isDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: isDown) else { continue }
                event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                event.flags = []   // plain text, even if you're holding ⌘ on your keyboard
                event.post(tap: .cghidEventTap)
            }
        }
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

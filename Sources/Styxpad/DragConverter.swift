// Makes "hold a Tartarus key mapped to a mouse click, then move the mouse" drag, like holding
// a real mouse button. Our synthetic button press doesn't make macOS treat your real mouse's
// movement as dragging, so while such a key is held, this catches macOS's "mouse moved" events
// and turns them into "mouse dragged" events before apps see them.

import CoreGraphics
import os

private let log = Logger(subsystem: "com.danielschultz.Styxpad", category: "drag")

final class DragConverter {
    /// The mouse buttons Tartarus keys are holding down right now.
    private var heldButtons: Set<CGMouseButton> = []

    /// The event tap: a hook that sees mouse events before apps do. Made the first time it's
    /// needed, then only switched on while a button is held, so normal mouse movement is untouched.
    private var tap: CFMachPort?

    /// Call whenever a Tartarus key presses or releases a mouse button.
    func buttonChanged(_ button: CGMouseButton, isDown: Bool) {
        if isDown { heldButtons.insert(button) } else { heldButtons.remove(button) }
        if !heldButtons.isEmpty && tap == nil { createTap() }
        if let tap { CGEvent.tapEnable(tap: tap, enable: !heldButtons.isEmpty) }
    }

    private func createTap() {
        // macOS calls this C-style function for each event, so it can't use `self` directly;
        // instead `self` is handed over as a raw pointer ("userInfo") and turned back here.
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            let converter = Unmanaged<DragConverter>.fromOpaque(userInfo!).takeUnretainedValue()
            converter.convert(event, type: type)
            return Unmanaged.passUnretained(event)   // pass the (possibly changed) event on
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.mouseMoved.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()   // safe: the app keeps this object for its whole life
        ) else {
            log.error("Couldn't create the drag event tap (Accessibility permission missing?)")
            return
        }
        // Deliver its events on the main thread, where the Remapper also runs.
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        self.tap = tap
    }

    /// Turns a "mouse moved" into a "mouse dragged" for the held button.
    private func convert(_ event: CGEvent, type: CGEventType) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS switches a tap off if it ever responds too slowly; switch it back on.
            if let tap, !heldButtons.isEmpty { CGEvent.tapEnable(tap: tap, enable: true) }
        case .mouseMoved:
            if heldButtons.contains(.left) {
                event.type = .leftMouseDragged
            } else if heldButtons.contains(.right) {
                event.type = .rightMouseDragged
            } else if let button = heldButtons.first {
                event.type = .otherMouseDragged
                event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.rawValue))
            }
        default:
            break
        }
    }
}

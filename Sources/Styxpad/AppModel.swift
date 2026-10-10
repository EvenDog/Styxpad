// Wires the pieces together: the USB device listener feeds key presses into the remapper,
// and the UI reads the status text and "which key is being pressed right now" from here.

import AppKit
import Observation

@Observable
final class AppModel {
    let store: ProfileStore
    var statusText = "Starting…"
    /// The physical keys currently held on the Tartarus, so the editor can highlight them.
    var livePressedKeyIDs: Set<String> = []
    /// True while the Hypershift key is held, so the editor can show the Hypershift layer.
    var isHypershiftHeld = false

    // "@ObservationIgnored" = the UI doesn't need to watch these, so don't track them.
    @ObservationIgnored private let device = TartarusDevice()
    @ObservationIgnored private let remapper: Remapper

    init() {
        let store = ProfileStore()
        self.store = store
        self.remapper = Remapper(store: store)

        Permissions.requestMissing()

        device.onKey = { [weak self] usage, isDown in
            guard let self else { return }
            remapper.handle(hidUsage: usage, isDown: isDown)
            isHypershiftHeld = remapper.isHypershiftHeld
            if let keyID = TartarusLayout.key(forHIDUsage: usage)?.id {
                if isDown { livePressedKeyIDs.insert(keyID) } else { livePressedKeyIDs.remove(keyID) }
            } else if isDown {
                // Helps us fix TartarusLayout.swift if a key sends something unexpected.
                print("Styxpad: unrecognized key \(KeyCodes.name(forHIDUsage: usage))")
            }
        }
        device.onStatusChange = { [weak self] text in self?.statusText = text }
        device.onDisconnect = { [weak self] in
            guard let self else { return }
            remapper.releaseAll()
            livePressedKeyIDs = []
            isHypershiftHeld = false
        }
        device.start()

        // When the app quits, give the Tartarus its normal keys back.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.device.stop()
        }
    }
}

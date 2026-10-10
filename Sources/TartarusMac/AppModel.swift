// Wires the pieces together: the USB device listener feeds key presses into the remapper,
// and the UI reads the status text and "which key is being pressed right now" from here.

import Observation

@Observable
final class AppModel {
    let store: ProfileStore
    var statusText = "Starting…"
    /// The physical key currently held on the Tartarus, so the editor can highlight it.
    var livePressedKeyID: String?

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
            livePressedKeyID = isDown ? TartarusLayout.key(forHIDUsage: usage)?.id : nil
            if isDown && TartarusLayout.key(forHIDUsage: usage) == nil {
                // Helps us fix TartarusLayout.swift if a key sends something unexpected.
                print("TartarusMac: unrecognized key \(KeyCodes.name(forHIDUsage: usage))")
            }
        }
        device.onStatusChange = { [weak self] text in self?.statusText = text }
        device.onDisconnect = { [weak self] in self?.remapper.releaseAll() }
        device.start()
    }
}

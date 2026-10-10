// Wires the pieces together: the USB device listener feeds key presses into the remapper,
// and the UI reads the status text and "which key is being pressed right now" from here.

import AppKit
import Observation

@Observable
final class AppModel {
    let store: ProfileStore
    var statusText = "Starting…"
    var isConnected = false
    /// The physical keys currently held on the Tartarus, so the editor can highlight them.
    var livePressedKeyIDs: Set<String> = []
    /// True while the Hypershift key is held, so the editor can show the Hypershift layer.
    var isHypershiftHeld = false
    /// When each key was last pressed (seconds since 2001, the clock SwiftUI's TimelineView
    /// uses), so the on-screen Reactive lighting preview can flash it.
    var lastPressTimes: [String: Double] = [:]

    /// The active profile's position in the list (0, 1 or 2) — also which side light is on.
    var activeProfileIndex: Int? {
        store.profiles.firstIndex { $0.id == store.activeProfileID }
    }

    // "@ObservationIgnored" = the UI doesn't need to watch these, so don't track them.
    @ObservationIgnored private let device = TartarusDevice()
    @ObservationIgnored private let remapper: Remapper
    /// Which profile (by position in the list) the side lights currently show, so we only
    /// send a command when it changes — not on every rename or key mapping edit.
    @ObservationIgnored private var shownProfileIndex: Int?
    /// The backlight settings the Tartarus is currently showing (same idea as above).
    @ObservationIgnored private var shownBacklight: BacklightSettings?

    /// Which of the 3 side lights is on for each profile: one light per profile
    /// (that's why ProfileStore allows at most 3 profiles).
    private static let sideLightPatterns: [(light1: Bool, light2: Bool, light3: Bool)] = [
        (true, false, false),   // profile 1
        (false, true, false),   // profile 2
        (false, false, true),   // profile 3
    ]

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
                if isDown {
                    livePressedKeyIDs.insert(keyID)
                    lastPressTimes[keyID] = Date().timeIntervalSinceReferenceDate
                } else {
                    livePressedKeyIDs.remove(keyID)
                }
            } else if isDown {
                // Helps us fix TartarusLayout.swift if a key sends something unexpected.
                print("Styxpad: unrecognized key \(KeyCodes.name(forHIDUsage: usage))")
            }
        }
        device.onStatusChange = { [weak self] text in
            guard let self else { return }
            statusText = text
            isConnected = device.isConnected
        }
        device.onDisconnect = { [weak self] in
            guard let self else { return }
            remapper.releaseAll()
            livePressedKeyIDs = []
            isHypershiftHeld = false
            shownProfileIndex = nil
            shownBacklight = nil
        }

        // Keep the side lights showing which profile is active, and the backlight showing
        // that profile's lighting.
        store.onChange = { [weak self] in self?.updateLighting() }
        device.onLightingReady = { [weak self] in
            // Freshly connected: we don't know what it's showing, so send everything.
            self?.shownProfileIndex = nil
            self?.shownBacklight = nil
            self?.updateLighting()
        }

        device.start()

        // When the app quits, give the Tartarus its normal keys back.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.device.stop()
        }
    }

    private func updateLighting() {
        updateSideLights()
        updateBacklight()
    }

    /// Lights up the side light(s) for the active profile, unless they already show it.
    private func updateSideLights() {
        guard let index = store.profiles.firstIndex(where: { $0.id == store.activeProfileID }),
              index != shownProfileIndex else { return }
        let pattern = Self.sideLightPatterns[index % Self.sideLightPatterns.count]
        let report = RazerProtocol.sideLightsReport(light1: pattern.light1, light2: pattern.light2, light3: pattern.light3)
        // Only remember it as shown if the Tartarus actually answered (it may not be plugged in).
        if device.sendCommand(report) != nil {
            shownProfileIndex = index
        }
    }

    /// Sends the active profile's backlight effect and brightness — only the parts that changed.
    private func updateBacklight() {
        let settings = store.activeProfile.backlight ?? BacklightSettings()
        guard settings != shownBacklight else { return }

        // Brightness is its own command. Compare everything *except* brightness to decide whether
        // the effect needs resending, so dragging the brightness slider only sends brightness.
        var newIgnoringBrightness = settings
        newIgnoringBrightness.brightness = 0
        var shownIgnoringBrightness = shownBacklight
        shownIgnoringBrightness?.brightness = 0
        if newIgnoringBrightness != shownIgnoringBrightness {
            guard device.sendCommand(RazerProtocol.backlightEffectReport(settings)) != nil else { return }
        }
        if settings.brightness != shownBacklight?.brightness {
            guard device.sendCommand(RazerProtocol.brightnessReport(settings.brightness)) != nil else { return }
        }
        shownBacklight = settings
    }
}

// Sparkle owns the update lifecycle: checking, verified downloads, installation and relaunch.
// This wrapper exposes its state to SwiftUI and carries forward the old update preference.

import AppKit
import Combine
import Observation
import Sparkle

@Observable
final class UpdateChecker {
    var canCheckForUpdates = false
    var automaticallyChecksForUpdates = false
    var automaticallyDownloadsUpdates = false
    private(set) var startupError: String?
    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var observations = Set<AnyCancellable>()

    init() {
        Self.migratePreferences(in: .standard)
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
            .store(in: &observations)
        updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.automaticallyChecksForUpdates = $0 }
            .store(in: &observations)
        updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.automaticallyDownloadsUpdates = $0 }
            .store(in: &observations)
        do {
            try updater.start()
        } catch {
            startupError = "Updates couldn't start: \(error.localizedDescription)"
        }
    }

    func check() {
        guard canCheckForUpdates else { return }
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    // Change Sparkle's own preferences only in response to a user action. Its update dialog
    // can change these too; the observations above keep our Settings toggles in sync.
    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        controller.updater.automaticallyDownloadsUpdates = enabled
    }

    static func migratePreferences(in defaults: UserDefaults) {
        let oldKey = "checkForUpdatesAutomatically"
        let sparkleKey = "SUEnableAutomaticChecks"
        if defaults.object(forKey: sparkleKey) == nil,
           let oldValue = defaults.object(forKey: oldKey) as? Bool {
            defaults.set(oldValue, forKey: sparkleKey)
        }
    }
}

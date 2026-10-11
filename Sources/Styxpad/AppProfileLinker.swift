// Switches profiles automatically when you switch apps. Each profile can list apps
// ("Switches on for: Photoshop"); when one comes to the front, its profile becomes active,
// and when you leave it, Styxpad goes back to the profile you were using before.

import AppKit

final class AppProfileLinker {
    private let store: ProfileStore

    /// The profile you were on before a linked app switched it, to go back to afterwards.
    private var profileBeforeLinkedApp: UUID?
    /// The profile a linked app switched to. If the active profile is no longer this one,
    /// you changed it yourself (Side button or the window), so we leave your choice alone.
    private var profileChosenByApp: UUID?

    /// Apps that never change the profile. Parallels' main app comes to the front a moment after
    /// any Windows app does (checked with Hatch in Coherence mode), so it mustn't count as
    /// "you left the linked app".
    private static let ignoredAppIDs: Set<String> = ["com.parallels.desktop.console"]

    init(store: ProfileStore) {
        self.store = store
        // macOS announces every time a different app comes to the front.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.appCameToFront(app?.bundleIdentifier)
        }
        appCameToFront(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)   // the app in front at launch
    }

    private func appCameToFront(_ bundleID: String?) {
        // Opening Styxpad's own window doesn't count, so you can edit the profile you're in.
        guard let bundleID, bundleID != Bundle.main.bundleIdentifier,
              !Self.ignoredAppIDs.contains(bundleID) else { return }
        let stillOnAppsChoice = profileChosenByApp != nil && store.activeProfileID == profileChosenByApp

        if let linkedProfile = store.profiles.first(where: { $0.linkedAppIDs?.contains(bundleID) == true }) {
            // Going from one linked app straight to another keeps the original profile to return to.
            if !stillOnAppsChoice { profileBeforeLinkedApp = store.activeProfileID }
            profileChosenByApp = linkedProfile.id
            if store.activeProfileID != linkedProfile.id { store.activeProfileID = linkedProfile.id }
        } else {
            // A regular app: go back, unless you've switched profile yourself in the meantime
            // (or the old profile was deleted).
            if stillOnAppsChoice, let previous = profileBeforeLinkedApp,
               store.profiles.contains(where: { $0.id == previous }) {
                store.activeProfileID = previous
            }
            profileBeforeLinkedApp = nil
            profileChosenByApp = nil
        }
    }
}

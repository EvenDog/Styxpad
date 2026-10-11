// Checks GitHub for a newer Styxpad release: at launch and then once a day, unless turned off
// in Settings. It only reads GitHub's public "latest release" information; nothing about you
// is sent. When there's a newer version, the menu bar menu and the window offer to open its
// download page (Styxpad doesn't install updates itself).

import Foundation
import Observation

@Observable
final class UpdateChecker {
    /// The Settings switch "Check for updates automatically" (saved in the app's preferences).
    static let automaticCheckKey = "checkForUpdatesAutomatically"

    struct Release: Equatable {
        let version: String   // e.g. "0.3"
        let pageURL: URL      // the release's page on GitHub, with the download
    }

    /// A newer release than this copy of Styxpad, once a check has found one.
    var availableUpdate: Release?
    /// "Later" on the window banner hides it until Styxpad restarts (the menu item stays).
    var isBannerDismissed = false
    /// What the last check found, in words, for the Settings window.
    var lastCheckResult: String?
    var isChecking = false

    /// This copy's version, from Info.plist (e.g. "0.2").
    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    /// GitHub's public API address for the newest published release (drafts don't count).
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/EvenDog/Styxpad/releases/latest")!
    @ObservationIgnored private var dailyTimer: Timer?

    init() {
        UserDefaults.standard.register(defaults: [Self.automaticCheckKey: true])   // on unless turned off
        checkIfAutomatic()
        dailyTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.checkIfAutomatic()
        }
    }

    private func checkIfAutomatic() {
        guard UserDefaults.standard.bool(forKey: Self.automaticCheckKey) else { return }
        Task { await check() }
    }

    /// Asks GitHub for the latest release and compares it with this version.
    /// "@MainActor" = run on the main thread, because the UI reads these properties.
    @MainActor func check() async {
        isChecking = true
        defer { isChecking = false }   // "defer" runs this when the function ends, however it ends

        // The two fields we need from GitHub's answer (it has many more).
        struct GitHubRelease: Decodable {
            let tagName: String   // e.g. "v0.3"
            let htmlURL: URL
            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlURL = "html_url"
            }
        }

        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let latest = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = latest.tagName.hasPrefix("v") ? String(latest.tagName.dropFirst()) : latest.tagName

            if Self.isVersion(latestVersion, newerThan: currentVersion) {
                availableUpdate = Release(version: latestVersion, pageURL: latest.htmlURL)
                lastCheckResult = "Styxpad \(latestVersion) is available."
            } else {
                availableUpdate = nil
                lastCheckResult = "You have the latest version (\(currentVersion))."
            }
        } catch {
            lastCheckResult = "Couldn't reach GitHub. Check your internet connection and try again."
        }
    }

    /// Compares versions number by number, so "0.10" counts as newer than "0.9"
    /// (comparing them as text would get that wrong). Missing numbers count as 0: "1.0" = "1".
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let currentParts = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(candidateParts.count, currentParts.count) {
            let new = index < candidateParts.count ? candidateParts[index] : 0
            let old = index < currentParts.count ? currentParts[index] : 0
            if new != old { return new > old }
        }
        return false   // the same version
    }
}

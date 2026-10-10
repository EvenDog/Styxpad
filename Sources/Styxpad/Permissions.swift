// Asks macOS for the two privacy permissions this app needs:
// - Input Monitoring: to read key presses from the Tartarus.
// - Accessibility: to type the remapped keys into other apps.
// Also: restarting the app, which macOS needs before a new Input Monitoring permission applies.

import AppKit
import CoreGraphics

enum Permissions {
    static var canReadInput: Bool { CGPreflightListenEventAccess() }
    static var canSendKeys: Bool { CGPreflightPostEventAccess() }

    /// Shows macOS's permission prompts for whichever permissions haven't been granted yet.
    static func requestMissing() {
        if !canReadInput { CGRequestListenEventAccess() }
        if !canSendKeys { CGRequestPostEventAccess() }
    }

    /// The first time: shows macOS's own prompt (which also adds Styxpad to the list in
    /// System Settings). After that macOS won't prompt again, so we open the settings page instead.
    static func requestInputMonitoring() {
        request(key: "askedForInputMonitoring", page: "Privacy_ListenEvent") { CGRequestListenEventAccess() }
    }

    static func requestAccessibility() {
        request(key: "askedForAccessibility", page: "Privacy_Accessibility") { CGRequestPostEventAccess() }
    }

    /// Opens the right page of System Settings so the user can switch the permission on.
    static func openSettings() {
        openSettingsPage(canReadInput ? "Privacy_Accessibility" : "Privacy_ListenEvent")
    }

    /// Quits and reopens Styxpad (macOS only applies a new Input Monitoring permission after a restart).
    static func relaunch() {
        // A tiny shell command waits a moment, then reopens the app after this copy has quit.
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        reopen.arguments = ["-c", "sleep 1; /usr/bin/open \"\(Bundle.main.bundlePath)\""]
        try? reopen.run()
        NSApp.terminate(nil)
    }

    private static func request(key: String, page: String, prompt: () -> Bool) {
        if UserDefaults.standard.bool(forKey: key) {
            openSettingsPage(page)
        } else {
            UserDefaults.standard.set(true, forKey: key)
            _ = prompt()
        }
    }

    private static func openSettingsPage(_ page: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(page)") {
            NSWorkspace.shared.open(url)
        }
    }
}

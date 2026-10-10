// Asks macOS for the two privacy permissions this app needs:
// - Input Monitoring: to read key presses from the Tartarus.
// - Accessibility: to type the remapped keys into other apps.

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

    /// Opens the right page of System Settings so the user can switch the permission on.
    static func openSettings() {
        let page = canReadInput ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(page)") {
            NSWorkspace.shared.open(url)
        }
    }
}

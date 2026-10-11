// The Settings window (open at login, updates, permissions, welcome screen) and the About panel.

import ServiceManagement   // Apple's framework for login items ("open at login")
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(WelcomeView.completedKey) private var hasCompletedWelcome = false
    @AppStorage(UpdateChecker.automaticCheckKey) private var checksForUpdates = true
    // SMAppService.mainApp = "this app" as a login item. We mirror its status in a @State
    // so the toggle can show it and change it.
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        // Re-check the permissions every second while Settings is open.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Form {
                Section("General") {
                    Toggle("Open Styxpad at login", isOn: $opensAtLogin)
                        .onChange(of: opensAtLogin) { _, shouldOpen in setOpensAtLogin(shouldOpen) }
                    if SMAppService.mainApp.status == .requiresApproval {
                        HStack {
                            Text("macOS needs you to approve this in Login Items.")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                        }
                    }
                    if let loginItemError {
                        Text(loginItemError).foregroundStyle(.orange)
                    }
                }

                Section("Updates") {
                    Toggle("Check for updates automatically", isOn: $checksForUpdates)
                        .help("Once a day, Styxpad asks GitHub whether a newer version has been released")
                    HStack {
                        Text(model.updates.lastCheckResult ?? "Styxpad \(model.updates.currentVersion)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let update = model.updates.availableUpdate {
                            Button("Download \(update.version)…") { NSWorkspace.shared.open(update.pageURL) }
                        }
                        Button("Check Now") { Task { await model.updates.check() } }
                            .disabled(model.updates.isChecking)
                    }
                }

                Section("Permissions") {
                    PermissionRow(title: "Input Monitoring", detail: "Reads your Tartarus's key presses",
                                  isGranted: Permissions.canReadInput) { Permissions.requestInputMonitoring() }
                    PermissionRow(title: "Accessibility", detail: "Types your remapped keys",
                                  isGranted: Permissions.canSendKeys) { Permissions.requestAccessibility() }
                }

                Section {
                    Button("Show Welcome Screen Again") { hasCompletedWelcome = false }
                    Button("About Styxpad") { showAboutPanel() }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)   // hide the standard grey, so the Styx ink shows
            .background(Theme.ink)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .tint(Theme.river)
        .preferredColorScheme(.dark)
        .onAppear { NSApp.activate() }   // menu bar apps don't come to the front on their own
    }

    private func setOpensAtLogin(_ shouldOpen: Bool) {
        do {
            if shouldOpen {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Couldn't change this: \(error.localizedDescription)"
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// "Input Monitoring — Reads your key presses … ✓ Allowed" or an Allow button.
private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let request: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.river)
            } else {
                Button("Allow…", action: request)
            }
        }
    }
}

/// Shows the standard macOS About window, with credits.
func showAboutPanel() {
    let credits = NSMutableAttributedString(
        string: "Key remapping for Razer Tartarus keypads on macOS.\n\n"
            + "Lighting protocol based on public research by the OpenRazer and CommandPost projects.\n\n"
            + "Not affiliated with or endorsed by Razer Inc. Released under the MIT License.",
        attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
    )
    // Center the text, like Apple's own About windows.
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))

    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
}

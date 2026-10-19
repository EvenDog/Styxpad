// The Settings window (open at login, lights, updates, permissions, welcome screen) and the About panel.

import ServiceManagement   // Apple's framework for login items ("open at login")
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(WelcomeView.completedKey) private var hasCompletedWelcome = false
    @AppStorage(AppModel.lightsOffWhileAwayKey) private var lightsOffWhileAway = true
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
                    Toggle("Turn off the lights while your Mac sleeps or is locked", isOn: $lightsOffWhileAway)
                }

                Section("Updates") {
                    Toggle("Check for updates automatically", isOn: Binding(
                        get: { model.updates.automaticallyChecksForUpdates },
                        set: { model.updates.setAutomaticallyChecksForUpdates($0) }
                    ))
                    Toggle("Download updates automatically", isOn: Binding(
                        get: { model.updates.automaticallyDownloadsUpdates },
                        set: { model.updates.setAutomaticallyDownloadsUpdates($0) }
                    ))
                    .disabled(!model.updates.automaticallyChecksForUpdates)
                    Text("Downloaded updates install when you quit Styxpad, or you can choose to install and restart sooner. Your profiles are kept.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Styxpad \(model.updates.currentVersion)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Check for Updates…") { model.updates.check() }
                            .disabled(!model.updates.canCheckForUpdates)
                    }
                    if let error = model.updates.startupError {
                        Text(error).foregroundStyle(.orange)
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
            + "Automatic updates powered by Sparkle (MIT License).\n\n"
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

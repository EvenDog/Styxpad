// The first-launch screen: three steps (Input Monitoring, Accessibility, plug in the Tartarus),
// each with a checkmark that updates live, so a new user knows exactly what to do and why.

import SwiftUI

struct WelcomeView: View {
    /// Saved once the user finishes (or skips) the welcome screen, so it isn't shown again.
    static let completedKey = "hasCompletedWelcome"

    @Environment(AppModel.self) private var model
    let onFinish: () -> Void

    var body: some View {
        // Re-check the permissions every second, so checkmarks appear as soon as they're granted.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let inputDone = Permissions.canReadInput
            let accessibilityDone = Permissions.canSendKeys
            let deviceDone = model.isConnected

            VStack(spacing: 28) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 104, height: 104)

                VStack(spacing: 8) {
                    Text("Welcome to Styxpad")
                        .font(Theme.display(32))
                    Text("Three quick steps and your Tartarus Pro is ready.")
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(spacing: 12) {
                    StepRow(number: 1, title: "Allow Input Monitoring",
                            detail: "Lets Styxpad read the key presses from your Tartarus.",
                            isDone: inputDone) {
                        Button("Allow…") { Permissions.requestInputMonitoring() }
                    }
                    StepRow(number: 2, title: "Allow Accessibility",
                            detail: "Lets Styxpad type your remapped keys into other apps.",
                            isDone: accessibilityDone) {
                        Button("Allow…") { Permissions.requestAccessibility() }
                    }
                    StepRow(number: 3, title: "Connect your Tartarus Pro",
                            detail: deviceStepDetail(inputDone: inputDone),
                            isDone: deviceDone) {
                        // macOS only applies a new Input Monitoring permission after a restart.
                        if inputDone && model.deviceAccessDenied {
                            Button("Restart Styxpad") { Permissions.relaunch() }
                        }
                    }
                }
                .frame(width: 540)

                VStack(spacing: 12) {
                    Button("Start Using Styxpad") { finish() }
                        .buttonStyle(PillButtonStyle(prominent: true))
                        .frame(width: 260)
                        .disabled(!(inputDone && accessibilityDone && deviceDone))
                    Button("Skip for now") { finish() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func deviceStepDetail(inputDone: Bool) -> String {
        if model.isConnected { return "Connected and ready." }
        if inputDone && model.deviceAccessDenied { return "Almost there — Styxpad needs a restart to use the new permission." }
        return "Plug it into a USB port on your Mac."
    }

    private func finish() {
        onFinish()
    }
}

/// One step: a numeral (or a checkmark once done), a title and explanation, and an action button.
private struct StepRow<Action: View>: View {
    let number: Int
    let title: String
    let detail: String
    let isDone: Bool
    @ViewBuilder let action: Action

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isDone ? Theme.river : Theme.raised)
                    .overlay(Circle().strokeBorder(isDone ? Color.clear : Theme.borderStrong))
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.riverInk)
                } else {
                    Text(romanNumeral(number))
                        .font(Theme.display(14))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .bold))
                Text(detail).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            if !isDone {
                action
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isDone ? Theme.river.opacity(0.4) : Theme.border))
        .animation(.easeOut(duration: 0.2), value: isDone)
    }
}

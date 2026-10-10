// The app's starting point. It creates two things:
// - the key-mapping editor window, and
// - a menu bar icon (top-right of the screen) for switching profiles and quitting.

import SwiftUI

@main
struct StyxpadApp: App {
    @State private var model = AppModel()
    // Connects our AppDelegate (below) so we hear app-level events like "reopen".
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Styxpad", id: "editor") {
            MainWindowView()
                .environment(model)
        }
        .defaultSize(width: 1100, height: 860)
        .windowToolbarStyle(.unified(showsTitle: false))   // the STYXPAD wordmark replaces the title

        MenuBarExtra {
            MenuContent()
                .environment(model)
        } label: {
            MenuBarIcon()
        }
    }
}

extension Notification.Name {
    /// Broadcast inside the app when the editor window should be shown.
    static let showEditor = Notification.Name("showEditor")
}

/// Receives app-level events from macOS. "Reopen" is what macOS sends when you open
/// (double-click, `open`, Spotlight) an app that's already running.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        // Only SwiftUI views can open windows, so ask the menu bar icon (always alive) to do it.
        NotificationCenter.default.post(name: .showEditor, object: nil)
        return true
    }
}

/// The keyboard icon in the menu bar. Besides being the icon, it listens for the
/// "show the editor" broadcast and opens the window.
struct MenuBarIcon: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "keyboard")
            .onReceive(NotificationCenter.default.publisher(for: .showEditor)) { _ in
                openWindow(id: "editor")
                NSApp.activate()   // menu bar apps don't come to the front on their own
            }
    }
}

/// The items shown when you click the menu bar icon.
struct MenuContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // "@Bindable" lets us create two-way bindings ($store.something) to an @Observable object.
        @Bindable var store = model.store

        Text(model.statusText)
        Divider()
        Picker("Profile", selection: $store.activeProfileID) {
            ForEach(store.profiles) { profile in
                Text(profile.name).tag(profile.id)
            }
        }
        .pickerStyle(.inline)
        Divider()
        Button("Open Styxpad…") {
            openWindow(id: "editor")
            NSApp.activate()   // menu bar apps don't come to the front on their own
        }
        if !Permissions.canReadInput || !Permissions.canSendKeys {
            Button("Grant Permissions…") { Permissions.openSettings() }
        }
        Divider()
        Button("Quit Styxpad") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

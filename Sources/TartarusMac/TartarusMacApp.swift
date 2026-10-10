// The app's starting point. It creates two things:
// - the key-mapping editor window, and
// - a menu bar icon (top-right of the screen) for switching profiles and quitting.

import SwiftUI

@main
struct TartarusMacApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Tartarus Key Mapper", id: "editor") {
            EditorView()
                .environment(model)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Tartarus", systemImage: "keyboard") {
            MenuContent()
                .environment(model)
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
        Button("Edit Key Mappings…") {
            openWindow(id: "editor")
            NSApp.activate()   // menu bar apps don't come to the front on their own
        }
        if !Permissions.canReadInput || !Permissions.canSendKeys {
            Button("Grant Permissions…") { Permissions.openSettings() }
        }
        Divider()
        Button("Quit TartarusMac") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

// The Macros tab: the macro library on the left, the selected macro on the right.
// Record a macro by typing on your keyboard; then any Tartarus key can play it
// (Keys tab → click a key → More Actions → Run Macro).

import SwiftUI

struct MacrosScreen: View {
    @Environment(AppModel.self) private var model
    @State private var selectedMacroID: UUID?

    var body: some View {
        let store = model.store

        HStack(alignment: .top, spacing: 24) {
            MacroList(macros: store.macros, selectedMacroID: $selectedMacroID) {
                selectedMacroID = store.addMacro()
            }
            .frame(width: 250)

            if let id = selectedMacroID, store.macros.contains(where: { $0.id == id }) {
                MacroEditor(macro: binding(forMacro: id)) {
                    selectedMacroID = store.macros.first { $0.id != id }?.id
                    store.deleteMacro(id)
                }
                .id(id)   // a fresh editor per macro, so switching macros stops any recording
            } else {
                emptyState
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { selectedMacroID = selectedMacroID ?? store.macros.first?.id }
    }

    /// A two-way connection to one macro in the library, found by its id. (Safer than using its
    /// position in the list, which changes when a macro is deleted.)
    private func binding(forMacro id: UUID) -> Binding<Macro> {
        let store = model.store
        return Binding(
            get: { store.macros.first { $0.id == id } ?? Macro(name: "") },
            set: { newValue in
                if let index = store.macros.firstIndex(where: { $0.id == id }) { store.macros[index] = newValue }
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "record.circle")
                .font(.system(size: 34))
                .foregroundStyle(Theme.river)
            Text("Macros play a recorded sequence of keys")
                .font(.system(size: 17, weight: .bold))
            Text("Make one with New Macro, record it on your keyboard, then give it to any Tartarus key in the Keys tab.")
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The library: one row per macro, plus a New Macro button.
private struct MacroList: View {
    let macros: [Macro]
    @Binding var selectedMacroID: UUID?
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MACROS")
                .font(Theme.display(12))
                .tracking(2.6)
                .foregroundStyle(Theme.textMuted)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(macros) { macro in
                        let isSelected = macro.id == selectedMacroID
                        Button { selectedMacroID = macro.id } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(macro.name)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                Text(macro.steps.isEmpty ? "Not recorded yet" : "\(macro.steps.count) steps")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Theme.riverDeep : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Theme.river : Color.clear))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("New Macro", action: onAdd)
                .buttonStyle(PillButtonStyle(prominent: macros.isEmpty))
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
    }
}

/// One macro: its name, the Record button, the delay setting and the list of steps.
private struct MacroEditor: View {
    @Binding var macro: Macro
    let onDelete: () -> Void

    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var lastKeyTime: TimeInterval?   // when the previous recorded key happened
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text(macro.name)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button("Rename…") {
                    renameText = macro.name
                    isRenaming = true
                }
                .buttonStyle(PillButtonStyle())
                .fixedSize()
                Button("Delete") { isConfirmingDelete = true }
                    .buttonStyle(PillButtonStyle())
                    .fixedSize()
            }

            HStack(spacing: 12) {
                Button(isRecording ? "Stop Recording" : (macro.steps.isEmpty ? "Record" : "Record Again")) {
                    isRecording ? stopRecording() : startRecording()
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .fixedSize()
                Text(isRecording ? "Type the keys on your keyboard, then click Stop Recording."
                                 : "Recording replaces the current steps.")
                    .foregroundStyle(isRecording ? Theme.river : Theme.textMuted)
            }

            HStack(spacing: 12) {
                Text("Delays")
                    .foregroundStyle(Theme.textSecondary)
                PillPicker(options: [("As Recorded", false), ("Fixed", true)],
                           selection: Binding(get: { macro.fixedDelay != nil },
                                              set: { useFixed in macro.fixedDelay = useFixed ? 50 : nil }))
                    .fixedSize()
                if let fixedDelay = macro.fixedDelay {
                    // A Stepper (− / + buttons) rather than a text box, so Tartarus keys can't type into it.
                    Stepper("\(fixedDelay) ms", value: Binding(get: { fixedDelay }, set: { macro.fixedDelay = $0 }),
                            in: 0...5000, step: 10)
                        .fixedSize()
                }
            }

            stepList
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
        .onDisappear { stopRecording() }
        .alert("Rename Macro", isPresented: $isRenaming) {
            TextField("Name", text: $renameText)
            Button("Rename") { macro.name = renameText }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete “\(macro.name)”?", isPresented: $isConfirmingDelete) {
            Button("Delete Macro", role: .destructive, action: onDelete)
        } message: {
            Text("Keys set to run this macro go back to their default.")
        }
    }

    /// The recorded steps, one row each: the pause before it, the key, and pressed/released.
    private var stepList: some View {
        ScrollView {
            VStack(spacing: 4) {
                if macro.steps.isEmpty && !isRecording {
                    Text("No steps yet. Click Record and type on your keyboard.")
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                }
                // "indices" = 0, 1, 2, ... — the position of each step in the list.
                ForEach(macro.steps.indices, id: \.self) { index in
                    let step = macro.steps[index]
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .foregroundStyle(Theme.textMuted)
                            .frame(width: 26, alignment: .trailing)
                        Text(index == 0 ? "—" : "\(macro.delay(before: index)) ms")
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 70, alignment: .trailing)
                        Text(KeyCodes.name(forMacKeyCode: step.keyCode))
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 90, alignment: .leading)
                        Text(step.isDown ? "↓ press" : "↑ release")
                            .foregroundStyle(step.isDown ? Theme.river : Theme.textMuted)
                        Spacer()
                        Button { macro.steps.remove(at: index) } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRecording)
                        .help("Delete this step")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink))
                }
            }
        }
    }

    /// Starts recording: every key you press and release in the window (and the time between them)
    /// becomes a step. Uses the same kind of "local monitor" as recording a single key in the Keys tab.
    private func startRecording() {
        macro.steps = []
        lastKeyTime = nil
        isRecording = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            if event.type == .keyDown && event.isARepeat { return nil }   // ignore auto-repeat while a key is held

            let isDown: Bool
            switch event.type {
            case .keyDown: isDown = true
            case .keyUp: isDown = false
            default:
                // A modifier key (Shift, ⌘, ...) changed. It's now down if its flag is on.
                guard let flag = KeyCodes.modifierFlagForMacKeyCode[event.keyCode] else { return nil }
                isDown = event.modifierFlags.rawValue & UInt(flag.rawValue) != 0
            }

            // event.timestamp is in seconds; the delay is the time since the previous key, in milliseconds.
            let delay = lastKeyTime.map { Int((event.timestamp - $0) * 1000) } ?? 0
            lastKeyTime = event.timestamp
            macro.steps.append(MacroStep(keyCode: event.keyCode, isDown: isDown, delay: delay))
            return nil   // swallow the event so it doesn't trigger anything in the app
        }
    }

    private func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        isRecording = false
    }
}

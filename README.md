# Styxpad

*Key remapping for Razer Tartarus keypads on macOS.*

A small "Razer Synapse" replacement for macOS: remap the keys on a Razer Tartarus Pro,
with profiles and a Hypershift layer.

## Build & run

```bash
./build-app.sh             # builds build/Styxpad.app
open build/Styxpad.app     # launches it (look for the keyboard icon in the menu bar)
```

On first launch macOS asks for two permissions. Turn both on in
**System Settings → Privacy & Security**, then quit (menu bar icon → Quit) and reopen the app:

- **Input Monitoring**: lets the app read the Tartarus's key presses.
- **Accessibility**: lets the app type the remapped keys.

## How it works

1. `TartarusDevice.swift` finds the Tartarus over USB and takes exclusive control of its keys.
2. `Remapper.swift` looks up each press in the active profile and types the replacement.
3. `EditorView.swift` is the window where you click a key and record what it should type.

Profiles are saved in `~/Library/Application Support/Styxpad/profiles.json`.

## Not supported

RGB lighting, actuation-point settings, and saving to the device's onboard memory all use
Razer's private, undocumented protocol. Remaps only work while the app is running.

## License

MIT — see [LICENSE](LICENSE).

Styxpad is an independent project and is not affiliated with or endorsed by Razer Inc.
"Razer" and "Tartarus" are trademarks of Razer Inc.

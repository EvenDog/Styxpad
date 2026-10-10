# Styxpad

*Key remapping for Razer Tartarus keypads on macOS.*

A small "Razer Synapse" replacement for macOS: remap the keys on a Razer Tartarus Pro,
with profiles and a Hypershift layer.

- **Remap** any key to another key or a shortcut (e.g. ⌘Z).
- **Hypershift:** hold a chosen key to give every other key a second function.
- **3 profiles**, one per side light. The Side button switches profiles (by default) and the
  side lights show which one is active.
- **Backlight effects per profile:** static, breathing, spectrum, wave, reactive, starlight
  or off, with colors, speed, direction and brightness.

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

1. `TartarusDevice.swift` finds the Tartarus over USB and listens to its keys. It mutes the
   Tartarus's own keys with Apple's `hidutil` (for that device only; undone when the app quits).
2. `Remapper.swift` looks up each press in the active profile and types the replacement.
3. `EditorView.swift` is the window where you click a key and record what it should type.
4. `RazerProtocol.swift` builds the lighting commands (side lights and backlight effects).

If the Tartarus's keys stop working after Styxpad crashes, unplug it and plug it back in.

Profiles are saved in `~/Library/Application Support/Styxpad/profiles.json`.

## Not supported

Per-key colors, actuation-point settings, and onboard key storage aren't supported.
Remaps only work while the app is running.

The lighting commands use Razer's undocumented protocol, implemented from public research
by the [OpenRazer](https://github.com/openrazer/openrazer) and CommandPost projects.

## License

MIT — see [LICENSE](LICENSE).

Styxpad is an independent project and is not affiliated with or endorsed by Razer Inc.
"Razer" and "Tartarus" are trademarks of Razer Inc.

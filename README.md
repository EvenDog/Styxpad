# Styxpad

*Key remapping for Razer Tartarus keypads on macOS.*

Razer Synapse doesn't run on the Mac, so out of the box a Tartarus Pro only types its factory
keys. Styxpad lets you remap every key, record macros, set up six profiles, and control the lighting.

![Styxpad's Keys screen](docs/keys.png)

## Features

- **Remap any key** to another key or a shortcut (e.g. ⌘Z). Click a key on the drawing of your
  Tartarus, press what it should type — done.
- **Remap the scroll wheel** too: rolling up, rolling down and clicking it can each do something
  else (e.g. volume up/down), in both Normal and Hypershift.
- **More than keys:** mouse clicks, scrolling, media keys (play/pause, volume, mute), opening an
  app or website, typing a saved phrase, or switching a key off.
- **Macros:** record a sequence of keys on your keyboard, then play it from any Tartarus key —
  once, over and over while the key is held, or on and off like a switch.
- **Turbo:** a held key repeats 5, 10 or 20 times a second.
- **Hypershift:** hold a key of your choice to give every other key a second function.
- **6 profiles**, each with its own pattern of side lights (top, middle, bottom, top two, bottom
  two, all three). The Side button switches profiles and the side lights show which one is active.
- **Profiles that follow your apps:** link apps to a profile and Styxpad switches to it whenever
  one of them is in front, then switches back when you leave.
- **Import and export** profiles to back them up or share them.
- **Updates inside the app:** check, download, install and restart from the menu bar or
  Settings. Automatic downloads can install when you quit, keeping your profiles.
- **Printable shortcut sheets:** open the profile menu → **Print Shortcut Sheet** for Normal,
  Hypershift, or a blank worksheet. Each sheet includes all 28 controls and a blank “What it
  does” column for handwritten notes. Use the print dialog’s PDF menu to save a copy.
- **Bring your Synapse setup along:** import a profile exported from Razer Synapse 4 on Windows
  (a `.synapse4` file). Each Synapse keymap becomes a Styxpad profile, and Ctrl shortcuts can be
  turned into ⌘ ones. Macro recordings and lighting don't come across yet; Styxpad lists what it
  skipped.
- **Backlight effects per profile:** static, breathing, spectrum, wave, reactive and starlight,
  with colors, speed and brightness — or paint every key its own color. Previewed live on
  screen. The lights turn off while your Mac is asleep or locked (you can change that in Settings).

![Styxpad's Lighting screen](docs/lighting.png)

## Install

1. Download **Styxpad-0.3.4.dmg** from the [Releases page](https://github.com/EvenDog/Styxpad/releases/latest).
2. Open it and drag **Styxpad** into **Applications**.
3. Open Styxpad. The welcome screen walks you through two permissions macOS requires:
   - **Input Monitoring** — so Styxpad can read your Tartarus's key presses.
   - **Accessibility** — so Styxpad can type your remapped keys.

Styxpad lives in the menu bar (the **[S]** keycap icon). Remaps work while it's running; turn on
**Open Styxpad at login** in Settings to have it always on.

![Installing Styxpad](docs/install.png)

**Requirements:** macOS 14 or later, Apple Silicon or Intel. Tested with the **Razer Tartarus Pro**;
other Tartarus models may work for remapping but are untested.

## Good to know

- Styxpad doesn't install any drivers. It mutes the Tartarus's own keys using Apple's built-in
  per-device key remapping, and gives them back when Styxpad quits.
- If the Tartarus's keys ever stop working after Styxpad crashes, unplug it and plug it back in.
- Styxpad uses [Sparkle](https://sparkle-project.org/) to check for signed updates once a day.
  Automatic checks and downloads can be turned off in Settings. Downloaded updates install
  when you quit, or choose **Check for Updates…** to install and restart sooner.
  Anonymous system profiling is disabled.
- Updating from 0.3.3 or earlier: install 0.3.4 once with the DMG to get the new updater.
  Future releases can then be installed inside the app.
- Updating from 0.1: once you've used 0.2's new actions or macros, don't go back to 0.1. It can't
  read them and starts over with a blank profile.
- To remap the scroll wheel, Styxpad takes it over while running and does the scrolling itself;
  quit Styxpad and the wheel scrolls on its own again.
- Not supported (yet): analog actuation settings.

## Build from source

You need Xcode (for Swift and its command-line tools).

```bash
./build-app.sh             # builds build/Styxpad.app
open build/Styxpad.app
```

`./make-release.sh` builds the signed, notarized DMG (it needs a Developer ID certificate and
notarization credentials — see the comments at the top of the script).
It also creates `release/appcast.xml`, the signed update feed. **Upload both the DMG and
appcast.xml to every GitHub release**, before making it the latest release. The feed URL uses
GitHub's latest-release download URL, so the installer and feed are published together.

Sparkle is pinned in `Package.swift` and `Package.resolved`. Both build scripts embed its
framework and sign its helper tools. Local builds default to Developer ID signing to match
the installed app's macOS permissions; another developer can set `SIGNING_IDENTITY` explicitly.
The update-signing private key stays in the macOS Keychain under Sparkle's `Styxpad` account.
The public key in `Resources/Info.plist` must match it; the release script checks this before
packaging. Do not regenerate the key for each release. New release notes can go in
`docs/release-notes/<version>.html`; the script embeds them in the signed feed.

Run `swift test` for updater preference migration checks.

### How it works

1. `TartarusDevice.swift` finds the Tartarus over USB and listens to its keys. It mutes the
   Tartarus's own keys with Apple's `hidutil` (for that device only; undone when the app quits),
   and takes exclusive control of the scroll wheel so its ticks and clicks can be remapped.
2. `Remapper.swift` looks up each press in the active profile and types the replacement, or runs
   its action: a click, a media key, a macro (`Macro.swift`), Turbo, and so on.
3. `MainWindow.swift` is the window: click a key on the drawing (`DeviceView.swift`) and a
   popover lets you record what it should type; the Lighting tab edits the backlight, and the
   Macros tab (`MacrosScreen.swift`) records macros.
4. `RazerProtocol.swift` builds the lighting commands (side lights and backlight effects).
5. `AppProfileLinker.swift` switches profiles when you switch apps.
6. `Theme.swift` holds the "Styx" colors and fonts.

Profiles and macros are saved in `~/Library/Application Support/Styxpad/profiles.json`.

## Credits

The lighting commands use Razer's undocumented protocol, implemented from public research by the
[OpenRazer](https://github.com/openrazer/openrazer) and CommandPost projects.

## License

MIT — see [LICENSE](LICENSE).

Styxpad is an independent project and is not affiliated with or endorsed by Razer Inc.
"Razer" and "Tartarus" are trademarks of Razer Inc.

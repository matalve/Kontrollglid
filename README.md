# Kontrollglid

A small macOS menu bar app that does two things for people who are used to Windows:

- **Glid** ("glide"): smooth scrolling for ordinary mouse wheels, separate scroll direction for mouse and trackpad, and extra mouse buttons as shortcuts.
- **Kontroll** ("control"): Windows keyboard shortcuts on an external PC keyboard. Ctrl+C, Home/End, Alt+Tab and friends work the way you expect.

The app has no network code, no dependencies and no telemetry. Settings are stored locally in `UserDefaults`.

## Features

### Mouse and trackpad

- Smooth scrolling for mouse wheels with adjustable step, speed and smoothness.
- A mode without acceleration: every notch of the wheel scrolls a fixed number of lines, with no animation and without the sluggish start macOS has.
- Scroll direction per device type: follow macOS, like Windows, or natural.
- Hold Shift to scroll sideways, Alt to scroll faster and Cmd to pause smoothing. All three can be changed.
- Extra mouse buttons (middle, back, forward …) can be assigned to any key combination.
- Per-app rules.

Three-finger swipes follow the macOS "Natural scrolling" setting, which the app cannot change. For natural trackpad gestures and a Windows-style wheel, turn Natural scrolling on in macOS and set the mouse wheel to "Like Windows" in Kontrollglid.

### Keyboard

| You press | macOS receives | Effect |
| --- | --- | --- |
| Ctrl + letter/digit | ⌘ + same key | Copy, paste, undo, save, find … |
| Ctrl+Y | ⇧⌘Z | Redo |
| Ctrl+Insert / Shift+Insert | ⌘C / ⌘V | Copy / paste |
| Home / End | ⌘← / ⌘→ | Start / end of the line |
| Ctrl+Home / Ctrl+End | ⌘↑ / ⌘↓ | Start / end of the document |
| Ctrl+← / Ctrl+→ | ⌥← / ⌥→ | Move by word |
| Ctrl+Backspace / Ctrl+Delete | ⌥⌫ / ⌥⌦ | Delete a word |
| Alt+Tab | ⌘⇥ | Switch app |
| Alt+F4 / Ctrl+F4 | ⌘Q / ⌘W | Quit app / close window |
| F5 | ⌘R | Reload |
| Print Screen | ⇧⌘5 | Screenshot tool |
| Win+L / Win+E | ⌃⌘Q / Finder | Lock the screen / open Finder |
| Win+← / Win+→ | ⌃← / ⌃→ | Switch desktop |
| AltGr+7 / 0 / plus / < / 5 | ⇧⌥8 / ⇧⌥9 / ⇧⌥7 / ⌥7 / ⇧4 | { } \\ \| € as on a Swedish PC keyboard |
| F2 / Delete in Finder | ↩ / ⌘⌫ | Rename / move to the Trash |

Shift can be added to select text. Every group can be turned off, and by default only external keyboards are translated.

Each app can be set to one of three modes:

- **Translate**: all rules apply.
- **Terminal mode**: Ctrl is left alone so Ctrl+C still interrupts, Home/End go to the start/end of the line, and Alt+Tab and the Win key keep working. Common terminals start in this mode.
- **Off**: nothing is translated. Remote desktops and virtual machines start in this mode.

The Keyboard tab has a key tester that shows which key code the app receives and what it would be translated to.

## Build and install

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
./scripts/install.sh
```

The script builds a Release version, puts it in `/Applications` and starts it. To work in Xcode, run `xcodegen generate` and open `Kontrollglid.xcodeproj`.

By default the app is signed ad hoc. macOS ties the Accessibility permission to the signature, so with ad-hoc signing you have to grant it again after every build. To avoid that, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and enter your own Apple developer team ID. That file is ignored by git.

Tests:

```bash
xcodebuild -project Kontrollglid.xcodeproj -scheme Kontrollglid -derivedDataPath build test
```

## Permissions

- **Accessibility** is required to read and change scroll, button and key events.
- **Input Monitoring** is only needed to tell whether a key press came from an external keyboard. If you choose "All keyboards" it is not needed.

## Code layout

- `Kontrollglid/Logic`: pure logic with no system dependencies: translation rules, scroll smoothing and the settings model. Covered by unit tests.
- `Kontrollglid/Engine`: event taps (`CGEventTap`) for scrolling, mouse buttons and the keyboard, plus keyboard identification through IOKit HID.
- `Kontrollglid/App` and `Kontrollglid/UI`: menu bar, settings window and storage.

## Background

The idea for the mouse features comes from [Mos](https://github.com/Caldis/Mos). Kontrollglid is written from scratch and shares no code with Mos.

## License

MIT, see [LICENSE](LICENSE).

# EdgeBar

**EdgeBar** is a lightweight macOS menu bar utility that turns the edges and corners of your MacBook Force Touch trackpad into tactile, zero-shortcut hardware and media controls — complete with native macOS HUD bars, cursor freeze while sliding, and palm/wrist rejection.

```
         ┌───────────────────────────────────────────┐
   [TL]  │  TOP EDGE (y ≥ 0.94, horizontal slide)    │  [TR]
   Corner│  ◀── decrease   Backlight   increase ──▶  │Corner
┌────────┼───────────────────────────────────────────┼────────┐
│ LEFT   │                                           │  RIGHT │
│ (x≤.04)│                                           │(x≥.96) │
│ Display│            Normal Trackpad Area           │  Sound │
│ Bright │                                           │ Volume │
├────────┴───────────────────────────────────────────┴────────┤
│  [BL] Corner                                  [BR] Corner   │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Configurable Edge Sliders (Left, Top, Right)**
  - Map any edge independently via dropdown to **Brightness**, **Sound**, **Backlight** (keyboard brightness), or **None**.
  - Default mapping: Left → Display Brightness, Top → Keyboard Backlight, Right → System Volume.
- **4-Corner Double-Tap Actions**
  - Configure **Top-Left**, **Top-Right**, **Bottom-Left**, and **Bottom-Right** corners independently:
    - `Mute / Unmute`, `Play / Pause`, `Next Track`, `Previous Track`
    - `Mission Control`, `Show Desktop`, `Lock Screen`, `Sleep Display`
    - `Toggle Dark Mode`, `Screenshot (Area to Clipboard)`, `Focus / DND` *(via an Apple Shortcut named `Toggle DND`)*
  - Bottom corners enforce a `0.4s` post-keypress typing cooldown when enabled so resting thumbs don't misfire.
- **Native macOS OSD Integration (`MenuBarAgent`)**
  - Uses 1/16th HID media key events (`IOHIDPostEvent`) when Accessibility is granted so macOS displays its built-in brightness, volume, and keyboard backlight bars in exact 1:1 sync.
  - Automatic fallback to direct `DisplayServices` / `CoreAudio` / `CoreBrightness` + frosted SwiftUI `HUDOverlay` if Accessibility hasn't been enabled yet.
- **Always-On Cursor Freeze While Sliding**
  - Uses a `.cghidEventTap` `CGEventTap` + pointer snap-back (`CGWarpMouseCursorPosition`) while sliding an edge so your cursor stays visibly locked in place instead of drifting across windows, with `0.8s` watchdog and app-termination fail-safes.
- **Always-On Palm & Wrist Rejection**
  - Filters oversized edge contacts using `OpenMultitouchSupport` elliptical axis (`majorAxis`, `minorAxis`) and capacitance (`total`) before activating a gesture.
- **Haptic Feedback & Persistent Settings**
  - Subtle Force Touch alignment pulses (`NSHapticFeedbackManager`) on activation and every 10% travel, plus `UserDefaults` persistence for all edge, corner, and haptic preferences.

---

## Requirements

- macOS 15+ (Apple Silicon built-in trackpad tested on macOS 26/27)
- Xcode or Apple Command Line Tools (Swift 6.2+)
- Python 3 (for `package-app.py`)

---

## Quick Build & Install

```bash
git clone https://github.com/Niru-26016/EdgeBar.git
cd EdgeBar
python3 package-app.py --install
open /Applications/EdgeBar.app
```

> [!NOTE]
> Pass `--release` to `python3 package-app.py --release --install` for an optimized release build.

### Permissions Setup
1. **Input Monitoring** (if prompted): Allows `OpenMultitouchSupport` to read trackpad edge touches globally.
2. **Accessibility** (**System Settings → Privacy & Security → Accessibility**): Required for macOS's native `MenuBarAgent` OSD bars, media key corners, and the `CGEventTap` cursor freeze. EdgeBar still adjusts brightness/volume/backlight with its fallback HUD without Accessibility.

---

## Architecture

| File | Role |
|---|---|
| `Sources/EdgeBar/EdgeBarApp.swift` | SwiftUI `MenuBarExtra` popover with Edge & Corner dropdown pickers |
| `Sources/EdgeBar/EdgeBarModel.swift` | Trackpad touch state machine, gesture thresholds, and haptics |
| `Sources/EdgeBar/EdgeBarConfig.swift` | Persisted `EdgeAction`, `CornerAction`, and `EdgeBarSettings` store |
| `Sources/EdgeBar/PalmRejection.swift` | Contact footprint filtering (`majorAxis`/`minorAxis`/`total`) and 4-corner double-tap detection |
| `Sources/EdgeBar/CursorFreeze.swift` | `CGEventTap` pointer freeze with `CGWarpMouseCursorPosition`, watchdog, and quit fail-safe |
| `Sources/EdgeBar/EdgeOutputRouter.swift` | Dispatches edge adjustments and corner system actions |
| `Sources/EdgeBar/SystemOSD.swift` | `IOHIDPostEvent` driver for native macOS brightness, volume, keyboard backlight, and media keys |
| `Sources/EdgeBar/HUDOverlay.swift` | Translucent SwiftUI capsule fallback HUD (`NSPanel`) |
| `Sources/EdgeBar/BrightnessController.swift` | Dynamic `DisplayServices` wrapper for built-in display backlight |
| `Sources/EdgeBar/VolumeController.swift` | `CoreAudio` default output scalar volume and mute control |
| `Sources/EdgeBar/KeyboardBrightnessController.swift` | Dynamic `CoreBrightness` (`KeyboardBrightnessClient`) wrapper |
| `package-app.py` | Portable `.app` bundler and ad-hoc code signer |

---

## Credits

- Built on top of the original [AnushRagu/EdgeBar](https://github.com/AnushRagu/EdgeBar) MVP prototype.
- Global multitouch trackpad input powered by [Kyome22/OpenMultitouchSupport](https://github.com/Kyome22/OpenMultitouchSupport).

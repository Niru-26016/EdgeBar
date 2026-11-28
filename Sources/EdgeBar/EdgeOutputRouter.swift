import Darwin
import Foundation

/// Dispatches edge adjustments (`EdgeAction`) and corner actions (`CornerAction`)
/// to either native macOS HUDs (`SystemOSD`) or direct hardware/system helpers.
@MainActor
final class EdgeOutputRouter {
    let brightness = BrightnessController()
    let volume = VolumeController()
    let keyboardBrightness = KeyboardBrightnessController()
    let osd = SystemOSD()
    let hud = HUDOverlay()

    private typealias CoreDockNotify = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void
    private typealias LockScreenFn = @convention(c) () -> Int32

    var hasSystemHUD: Bool { osd.isTrusted }

    func currentLevel(for action: EdgeAction) -> Float? {
        switch action {
        case .none: return nil
        case .brightness: return brightness.get()
        case .volume: return volume.get()
        case .keyboardBacklight: return keyboardBrightness.get()
        }
    }

    func showFallbackHUD(action: EdgeAction, value: Double) {
        switch action {
        case .none: break
        case .brightness: hud.showBrightness(value)
        case .volume: hud.showVolume(value)
        case .keyboardBacklight: hud.showKeyboardBrightness(value)
        }
    }

    /// Applies a normalized `0...1` adjustment for `action` and returns whether a native OSD step fired.
    func apply(action: EdgeAction, value: Double, useSystemHUD: Bool) -> (postedSystemStep: Bool, status: String) {
        if useSystemHUD {
            let posted: Bool
            switch action {
            case .none: posted = false
            case .brightness: posted = osd.updateBrightness(to: value)
            case .volume: posted = osd.updateVolume(to: value)
            case .keyboardBacklight: posted = osd.updateKeyboardBrightness(to: value)
            }
            return (posted, statusText(for: action))
        }

        switch action {
        case .none: break
        case .brightness: _ = brightness.set(Float(value))
        case .volume: volume.set(Float(value))
        case .keyboardBacklight: _ = keyboardBrightness.set(Float(value))
        }
        showFallbackHUD(action: action, value: value)
        return (false, statusText(for: action))
    }

    func performCornerAction(_ action: CornerAction, useSystemHUD: Bool) -> (syncVolume: Bool, directVolume: Float?, status: String) {
        switch action {
        case .none:
            return (false, nil, "Slide along an edge to adjust")
        case .mute:
            if useSystemHUD, osd.toggleMute() { return (true, nil, "Toggled mute") }
            if let level = volume.toggleMute() {
                hud.showVolume(Double(level))
                return (false, level, level == 0 ? "Muted" : "Unmuted")
            }
            return (false, nil, "Mute unavailable")
        case .playPause:
            let ok = osd.playPause()
            return (false, nil, ok ? "Play / Pause" : "Enable Accessibility for media keys")
        case .nextTrack:
            let ok = osd.nextTrack()
            return (false, nil, ok ? "Next track" : "Enable Accessibility for media keys")
        case .previousTrack:
            let ok = osd.previousTrack()
            return (false, nil, ok ? "Previous track" : "Enable Accessibility for media keys")
        case .missionControl:
            sendDockNotification("com.apple.expose.awake")
            return (false, nil, "Mission Control")
        case .showDesktop:
            sendDockNotification("com.apple.showdesktop.awake")
            return (false, nil, "Show Desktop")
        case .lockScreen:
            lockScreen()
            return (false, nil, "Locked screen")
        case .sleepDisplay:
            runDetached("/usr/bin/pmset", args: ["displaysleepnow"])
            return (false, nil, "Sleeping display")
        case .toggleDarkMode:
            toggleDarkMode()
            return (false, nil, "Toggled Dark Mode")
        case .screenshotArea:
            runDetached("/usr/sbin/screencapture", args: ["-i", "-c"])
            return (false, nil, "Screenshot to clipboard")
        case .toggleDND:
            runDetached("/usr/bin/shortcuts", args: ["run", "Toggle DND"])
            return (false, nil, "Toggled Focus (Shortcut: Toggle DND)")
        }
    }

    private func statusText(for action: EdgeAction) -> String {
        switch action {
        case .none: return "Slide along an edge to adjust"
        case .brightness: return "Adjusting brightness"
        case .volume: return "Adjusting sound"
        case .keyboardBacklight: return "Adjusting backlight"
        }
    }

    private func sendDockNotification(_ name: String) {
        guard let h = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY) else { return }
        defer { dlclose(h) }
        guard let sym = dlsym(h, "CoreDockSendNotification") else { return }
        let fn = unsafeBitCast(sym, to: CoreDockNotify.self)
        fn(name as CFString, nil)
    }

    private func lockScreen() {
        guard let h = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY) else { return }
        defer { dlclose(h) }
        guard let sym = dlsym(h, "SACLockScreenImmediate") else { return }
        let fn = unsafeBitCast(sym, to: LockScreenFn.self)
        _ = fn()
    }

    private func toggleDarkMode() {
        let source = """
        tell application "System Events"
            tell appearance preferences to set dark mode to not dark mode
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    private func runDetached(_ path: String, args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: path)
            task.arguments = args
            try? task.run()
        }
    }
}

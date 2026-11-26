import ApplicationServices
import Foundation
import IOKit
import IOKit.hidsystem

// NX_KEYTYPE_* constants from IOKit/hidsystem/ev_keymap.h
private let keySoundUp: Int32 = 0
private let keySoundDown: Int32 = 1
private let keyBrightnessUp: Int32 = 2
private let keyBrightnessDown: Int32 = 3

/// Posts standard 1/16th HID media key events through IOHIDSystem so every step
/// matches macOS's 16-segment MenuBarAgent bar 1:1 with zero modifier interference.
@MainActor
final class SystemOSD {
    nonisolated(unsafe) private var connect: io_connect_t = 0
    private var lastStep: Int?
    let totalSteps = 16

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        if service != 0 {
            let kr = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
            if kr != KERN_SUCCESS {
                connect = 0
            }
            IOObjectRelease(service)
        }
    }

    deinit {
        if connect != 0 {
            IOServiceClose(connect)
        }
    }

    func requestAccessibilityPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func beginGesture(currentValue: Double) {
        lastStep = stepIndex(for: currentValue)
    }

    func reset() {
        lastStep = nil
    }

    @discardableResult
    func updateBrightness(to value: Double) -> Bool {
        emitSteps(to: value, upKey: keyBrightnessUp, downKey: keyBrightnessDown)
    }

    @discardableResult
    func updateVolume(to value: Double) -> Bool {
        emitSteps(to: value, upKey: keySoundUp, downKey: keySoundDown)
    }

    private func emitSteps(to value: Double, upKey: Int32, downKey: Int32) -> Bool {
        guard isTrusted else { return false }
        let target = stepIndex(for: value)
        let previous = lastStep ?? target
        let diff = target - previous
        guard diff != 0 else {
            lastStep = target
            return false
        }

        let key = diff > 0 ? upKey : downKey
        let count = min(abs(diff), 4)
        for _ in 0..<count {
            postKey(key)
        }
        lastStep = target
        return true
    }

    private func stepIndex(for value: Double) -> Int {
        let clamped = max(0.0, min(1.0, value))
        return Int((clamped * Double(totalSteps)).rounded())
    }

    private func postKey(_ keyCode: Int32) {
        guard connect != 0 else { return }
        var ev = NXEventData()
        ev.compound.subType = Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS)

        ev.compound.misc.L.0 = (keyCode << 16) | (0x0a << 8)
        _ = IOHIDPostEvent(connect, UInt32(NX_SYSDEFINED), IOGPoint(x: 0, y: 0), &ev, UInt32(kNXEventDataVersion), 0, 0)

        ev.compound.misc.L.0 = (keyCode << 16) | (0x0b << 8)
        _ = IOHIDPostEvent(connect, UInt32(NX_SYSDEFINED), IOGPoint(x: 0, y: 0), &ev, UInt32(kNXEventDataVersion), 0, 0)
    }
}

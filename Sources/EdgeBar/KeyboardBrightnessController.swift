import Foundation
import ObjectiveC

/// Uses CoreBrightness dynamically because there is no public macOS API
/// for reading or setting the built-in keyboard backlight level.
@MainActor
final class KeyboardBrightnessController {
    private typealias GetBrightness = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetBrightness = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool

    private let client: AnyObject?
    private let getSel = NSSelectorFromString("brightnessForKeyboard:")
    private let setSel = NSSelectorFromString("setBrightness:forKeyboard:")
    private let getFn: GetBrightness?
    private let setFn: SetBrightness?
    private let keyboardID: UInt64

    init() {
        guard let bundle = Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework"),
              bundle.load(),
              let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
            client = nil
            getFn = nil
            setFn = nil
            keyboardID = 1
            return
        }

        let instance = cls.init()
        client = instance

        let idsSel = NSSelectorFromString("copyKeyboardBacklightIDs")
        if instance.responds(to: idsSel),
           let ids = instance.perform(idsSel)?.takeRetainedValue() as? [NSNumber],
           let first = ids.first {
            keyboardID = first.uint64Value
        } else {
            keyboardID = 1
        }

        if let m = class_getInstanceMethod(cls, getSel) {
            getFn = unsafeBitCast(method_getImplementation(m), to: GetBrightness.self)
        } else {
            getFn = nil
        }

        if let m = class_getInstanceMethod(cls, setSel) {
            setFn = unsafeBitCast(method_getImplementation(m), to: SetBrightness.self)
        } else {
            setFn = nil
        }
    }

    func get() -> Float? {
        guard let client, let getFn else { return nil }
        let value = getFn(client, getSel, keyboardID)
        guard value.isFinite, value >= 0 else { return nil }
        return min(1, max(0, value))
    }

    @discardableResult
    func set(_ value: Float) -> Bool {
        guard let client, let setFn else { return false }
        return setFn(client, setSel, min(1, max(0, value)), keyboardID)
    }
}

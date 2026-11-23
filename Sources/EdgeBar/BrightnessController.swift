import CoreGraphics
import Darwin
import Foundation

/// Uses DisplayServices dynamically because there is no supported macOS API
/// for changing the built-in Apple Silicon panel backlight.
final class BrightnessController {
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    private let handle: UnsafeMutableRawPointer?
    private let setBrightness: SetBrightness?

    init() {
        handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        )
        if let handle, let symbol = dlsym(handle, "DisplayServicesSetBrightness") {
            setBrightness = unsafeBitCast(symbol, to: SetBrightness.self)
        } else {
            setBrightness = nil
        }
    }

    deinit {
        if let handle { dlclose(handle) }
    }

    @discardableResult
    func set(_ value: Float) -> Bool {
        guard let setBrightness else { return false }
        return setBrightness(CGMainDisplayID(), min(1, max(0, value))) == 0
    }
}

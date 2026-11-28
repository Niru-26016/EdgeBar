import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

private final class TapState: @unchecked Sendable {
    var frozen = false
    var tap: CFMachPort?
}

/// Freezes the macOS pointer visibly in place while sliding an edge using a CGEventTap
/// on cghidEventTap (which intercepts Apple trackpad pointer movement) plus CGWarpMouseCursorPosition
/// snap-back, with watchdog and app-termination fail-safes.
@MainActor
final class CursorFreeze {
    private let tapState = TapState()
    private var runLoopSource: CFRunLoopSource?
    private var savedPoint: CGPoint?
    nonisolated(unsafe) private(set) var isFrozen = false
    private var watchdogTask: Task<Void, Never>?
    nonisolated(unsafe) private var terminationObserver: NSObjectProtocol?

    init() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [tapState] _ in
            MainActor.assumeIsolated {
                tapState.frozen = false
                if let tap = tapState.tap {
                    CGEvent.tapEnable(tap: tap, enable: false)
                }
                _ = CGAssociateMouseAndMouseCursorPosition(1)
            }
        }
    }

    deinit {
        tapState.frozen = false
        if let tap = tapState.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if isFrozen {
            _ = CGAssociateMouseAndMouseCursorPosition(1)
        }
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    func captureStartPoint() {
        guard !isFrozen else { return }
        savedPoint = CGEvent(source: nil)?.location
    }

    func freeze() {
        guard !isFrozen else {
            ping()
            return
        }
        let targetPoint = savedPoint ?? CGEvent(source: nil)?.location
        savedPoint = targetPoint
        ensureEventTap()
        tapState.frozen = true
        if let tap = tapState.tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        _ = CGAssociateMouseAndMouseCursorPosition(0)
        if let targetPoint {
            _ = CGWarpMouseCursorPosition(targetPoint)
        }
        isFrozen = true
        scheduleWatchdog()
    }

    func ping() {
        guard isFrozen else { return }
        if tapState.tap == nil, let savedPoint {
            _ = CGWarpMouseCursorPosition(savedPoint)
        }
        scheduleWatchdog()
    }

    func unfreeze() {
        watchdogTask?.cancel()
        watchdogTask = nil
        savedPoint = nil
        tapState.frozen = false
        if let tap = tapState.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        guard isFrozen else { return }
        _ = CGAssociateMouseAndMouseCursorPosition(1)
        isFrozen = false
    }

    private func ensureEventTap() {
        guard tapState.tap == nil, AXIsProcessTrusted() else { return }
        let mask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let state = Unmanaged<TapState>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if state.frozen, let machPort = state.tap {
                        CGEvent.tapEnable(tap: machPort, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }
                return state.frozen ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(tapState).toOpaque()
        ) else { return }

        tapState.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: false)
    }

    private func scheduleWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.unfreeze()
        }
    }
}

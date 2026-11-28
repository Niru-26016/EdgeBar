import AppKit
import Foundation
import Observation
import OpenMultitouchSupport

@MainActor
@Observable
final class EdgeBarModel {
    let settings = EdgeBarSettings()
    var isListening = false
    var hasSystemHUD = false
    var status = "Waiting for trackpad input"
    var brightnessLevel = 0.5
    var volumeLevel = 0.5
    var backlightLevel = 0.5

    private let manager = OMSManager.shared
    private let output = EdgeOutputRouter()
    private let palmRejection = PalmRejection()
    private let cursorFreeze = CursorFreeze()
    private var cornerTap = CornerDoubleTapDetector()
    private var streamTask: Task<Void, Never>?
    private var activeTouchID: Int32?
    private var activeSide: EdgeSide?
    private var activeEdgeAction: EdgeAction = .none
    private var activeCorner: CornerPosition?
    private var maxTapTravel: Double = 0
    private var lastHapticValue: Double?
    private var lastHapticTime: TimeInterval = 0
    private var startX: Double = 0
    private var startY: Double = 0
    private var startTime: TimeInterval = 0
    private var lastX: Double = 0
    private var lastY: Double = 0
    private var sliding = false
    private var blockedUntilLift = false
    private var slideValue: Double = 0

    init() {
        start()
        syncSystemLevels()
        if !hasSystemHUD {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.output.osd.requestAccessibilityPrompt()
            }
        }
    }

    func syncSystemLevels() {
        if let b = output.brightness.get() { brightnessLevel = Double(b) }
        if let v = output.volume.get() { volumeLevel = Double(v) }
        if let k = output.keyboardBrightness.get() { backlightLevel = Double(k) }
        hasSystemHUD = output.hasSystemHUD
    }

    func levelPercent(for action: EdgeAction) -> String? {
        switch action {
        case .none: return nil
        case .brightness: return "\(Int((brightnessLevel * 100).rounded()))%"
        case .volume: return "\(Int((volumeLevel * 100).rounded()))%"
        case .keyboardBacklight: return "\(Int((backlightLevel * 100).rounded()))%"
        }
    }

    func requestSystemHUD() {
        output.osd.requestAccessibilityPrompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        hasSystemHUD = output.hasSystemHUD
    }

    func start() {
        guard !isListening else { return }
        streamTask = Task { [weak self, manager] in
            for await touches in manager.touchDataStream {
                guard !Task.isCancelled else { break }
                self?.consume(touches)
            }
        }
        isListening = manager.startListening()
        status = isListening ? "Slide along an edge to adjust" : "Could not start trackpad listener"
    }

    private func consume(_ touches: [OMSTouchData]) {
        let active = touches.filter { $0.state == .touching || $0.state == .making }
        if active.isEmpty { handleLift(); return }
        guard !blockedUntilLift else { return }
        guard active.count == 1, let touch = active.first else { cancelTouch(); return }

        let fx = touch.position.x, fy = touch.position.y
        let x = Double(fx), y = Double(fy)
        guard x.isFinite, y.isFinite else { cancelTouch(); return }
        if palmRejection.isPalm(touch) { cancelTouch(); return }

        if activeTouchID == nil {
            let side = palmRejection.edgeSide(x: fx, y: fy)
            let edgeAction = side.map { settings.action(for: $0) } ?? .none
            let corner = cornerTap.corner(x: fx, y: fy)
            let cornerAction = corner.map { settings.action(for: $0) } ?? .none
            guard edgeAction != .none || cornerAction != .none else { cancelTouch(); return }

            activeTouchID = touch.id
            activeSide = edgeAction != .none ? side : nil
            activeEdgeAction = edgeAction
            activeCorner = cornerAction != .none ? corner : nil
            maxTapTravel = 0
            startX = x
            startY = y
            startTime = ProcessInfo.processInfo.systemUptime
            if activeSide != nil { cursorFreeze.captureStartPoint() }
            return
        }

        guard activeTouchID == touch.id else { cancelTouch(); return }
        maxTapTravel = max(maxTapTravel, hypot(x - startX, y - startY))
        guard let side = activeSide else {
            if maxTapTravel >= 0.025 { cancelTouch() }
            return
        }
        guard palmRejection.isWithinDriftBounds(side: side, x: fx, y: fy) else { cancelTouch(); return }

        if !sliding {
            let travel = side == .top ? abs(x - startX) : abs(y - startY)
            // Require 2.5% travel along the edge axis and 100 ms of contact. A tap cannot write a level.
            guard travel >= 0.025, ProcessInfo.processInfo.systemUptime - startTime >= 0.10 else { return }
            guard let current = output.currentLevel(for: activeEdgeAction) else {
                status = "Could not read current level"
                cancelTouch()
                return
            }
            sliding = true
            slideValue = Double(current)
            lastX = x
            lastY = y
            cursorFreeze.freeze()
            hasSystemHUD = output.hasSystemHUD
            if hasSystemHUD {
                output.osd.beginGesture(currentValue: slideValue)
            } else {
                output.showFallbackHUD(action: activeEdgeAction, value: slideValue)
            }
            updateHaptics(slideValue)
            return
        }

        cursorFreeze.ping()
        let delta = side == .top ? (x - lastX) : (y - lastY)
        guard abs(delta) >= 0.002 else { return }
        lastX = x
        lastY = y
        slideValue = min(1, max(0, slideValue + delta))
        applySlideAdjustment()
    }

    private func applySlideAdjustment() {
        updateHaptics(slideValue)
        hasSystemHUD = output.hasSystemHUD
        let result = output.apply(action: activeEdgeAction, value: slideValue, useSystemHUD: hasSystemHUD)
        status = result.status
        if hasSystemHUD {
            if result.postedSystemStep { schedulePreviewSync(for: activeEdgeAction) }
        } else {
            setLevel(slideValue, for: activeEdgeAction)
        }
    }

    private func handleLift() {
        cursorFreeze.unfreeze()
        let now = ProcessInfo.processInfo.systemUptime
        if !sliding && !blockedUntilLift && activeTouchID != nil, let corner = activeCorner {
            let mapped = settings.action(for: corner)
            if mapped != .none,
               cornerTap.registerLift(corner: corner, now: now, duration: now - startTime, travel: maxTapTravel) {
                triggerCornerAction(mapped)
            }
        } else if sliding {
            cornerTap.reset()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.syncSystemLevels() }
        }
        activeTouchID = nil
        activeSide = nil
        activeEdgeAction = .none
        activeCorner = nil
        maxTapTravel = 0
        lastHapticValue = nil
        sliding = false
        blockedUntilLift = false
        output.osd.reset()
    }

    private func cancelTouch() {
        blockedUntilLift = true
        cursorFreeze.unfreeze()
    }

    private func triggerCornerAction(_ action: CornerAction) {
        hasSystemHUD = output.hasSystemHUD
        if settings.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        let outcome = output.performCornerAction(action, useSystemHUD: hasSystemHUD)
        status = outcome.status
        if outcome.syncVolume {
            schedulePreviewSync(for: .volume)
        } else if let direct = outcome.directVolume {
            volumeLevel = Double(direct)
        }
    }

    private func setLevel(_ value: Double, for action: EdgeAction) {
        switch action {
        case .none: break
        case .brightness: brightnessLevel = value
        case .volume: volumeLevel = value
        case .keyboardBacklight: backlightLevel = value
        }
    }

    private func schedulePreviewSync(for action: EdgeAction) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self, let level = self.output.currentLevel(for: action) else { return }
            self.setLevel(Double(level), for: action)
        }
    }

    private func updateHaptics(_ value: Double) {
        guard value.isFinite else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let isActivation = lastHapticValue == nil
        guard isActivation || abs(value - (lastHapticValue ?? value)) >= 0.10 else { return }
        guard isActivation || now - lastHapticTime >= 0.08 else { return }
        lastHapticValue = value
        lastHapticTime = now
        guard settings.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

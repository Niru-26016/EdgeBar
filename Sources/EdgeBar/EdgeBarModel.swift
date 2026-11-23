import AppKit
import Foundation
import Observation
import OpenMultitouchSupport

@MainActor
@Observable
final class EdgeBarModel {
    var hapticsEnabled = true
    var isListening = false
    var status = "Waiting for trackpad input"
    var brightnessPreview = 0.5
    var volumePreview = 0.5

    private let manager = OMSManager.shared
    private let brightness = BrightnessController()
    private let volume = VolumeController()
    private var streamTask: Task<Void, Never>?
    private var activeTouchID: Int32?
    private var activeSide: EdgeSide?
    private var lastHapticValue: Double?
    private var lastHapticTime: TimeInterval = 0
    private var startY: Double = 0
    private var startTime: TimeInterval = 0
    private var lastY: Double = 0
    private var sliding = false
    private var blockedUntilLift = false
    private var slideValue: Double = 0
    private let edgeWidth: Float = 0.04

    init() {
        start()
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

    func setBrightness(_ value: Double) {
        brightnessPreview = value
        if brightness.set(Float(value)) {
            status = "Brightness adjusted"
        } else {
            status = "Brightness control unavailable on this display"
        }
    }

    func setVolume(_ value: Double) {
        volumePreview = value
        volume.set(Float(value))
        status = "Volume adjusted"
    }

    private func consume(_ touches: [OMSTouchData]) {
        let active = touches.filter { $0.state == .touching || $0.state == .making }
        if active.isEmpty {
            activeTouchID = nil
            activeSide = nil
            lastHapticValue = nil
            sliding = false
            blockedUntilLift = false
            return
        }
        guard !blockedUntilLift else { return }
        guard active.count == 1, let touch = active.first else {
            blockedUntilLift = true
            return
        }
        let x = touch.position.x
        let y = Double(touch.position.y)
        guard x.isFinite, y.isFinite else { blockedUntilLift = true; return }
        if activeTouchID == nil {
            guard x <= edgeWidth || x >= 1 - edgeWidth else {
                blockedUntilLift = true
                return
            }
            activeTouchID = touch.id
            activeSide = x <= edgeWidth ? .left : .right
            startY = y
            startTime = ProcessInfo.processInfo.systemUptime
            return
        }
        guard activeTouchID == touch.id, let side = activeSide,
              (side == .left ? x <= edgeWidth + 0.02 : x >= 1 - edgeWidth - 0.02) else {
            blockedUntilLift = true
            return
        }
        if !sliding {
            // Require 2.5% vertical travel and 100 ms of contact. A tap cannot write a level.
            guard abs(y - startY) >= 0.025,
                  ProcessInfo.processInfo.systemUptime - startTime >= 0.10 else { return }
            let current = side == .left ? brightness.get() : volume.get()
            guard let current else {
                status = "Could not read current level"
                blockedUntilLift = true
                return
            }
            sliding = true
            slideValue = Double(current)
            lastY = y
            updateHaptics(slideValue)
            return
        }
        let delta = y - lastY
        guard abs(delta) >= 0.002 else { return }
        lastY = y
        slideValue = min(1, max(0, slideValue + delta))
        let value = slideValue
        updateHaptics(value)
        switch side {
        case .left:
            brightnessPreview = value
            _ = brightness.set(Float(value))
            status = "Adjusting brightness"
        case .right:
            volumePreview = value
            volume.set(Float(value))
            status = "Adjusting volume"
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
        guard hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

private enum EdgeSide { case left, right }

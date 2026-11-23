import Foundation
import Observation
import OpenMultitouchSupport

@MainActor
@Observable
final class EdgeBarModel {
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
    private let edgeWidth: Float = 0.08

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
        guard active.count == 1, let touch = active.first else {
            if active.isEmpty {
                activeTouchID = nil
                activeSide = nil
            }
            return
        }

        if activeTouchID == nil {
            guard touch.position.x <= edgeWidth || touch.position.x >= 1 - edgeWidth else { return }
            activeTouchID = touch.id
            activeSide = touch.position.x <= edgeWidth ? .left : .right
        }

        guard activeTouchID == touch.id, let side = activeSide else { return }
        let value = min(1, max(0, Double(touch.position.y)))
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
}

private enum EdgeSide { case left, right }

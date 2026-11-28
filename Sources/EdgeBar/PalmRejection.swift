import CoreGraphics
import Foundation
import OpenMultitouchSupport

enum EdgeSide {
    case left, right, top
}

/// Tracks quick double-taps in any of the four trackpad corners with optional
/// typing-cooldown protection on bottom corners.
struct CornerDoubleTapDetector {
    var cornerSize: Float = 0.12
    var maxDuration: TimeInterval = 0.25
    var maxTravel: Double = 0.025
    var maxInterval: TimeInterval = 0.38
    var bottomTypingCooldown: TimeInterval = 0.40

    private var lastTap: (corner: CornerPosition, time: TimeInterval)?

    func corner(x: Float, y: Float) -> CornerPosition? {
        let isLeft = x <= cornerSize
        let isRight = x >= 1 - cornerSize
        let isTop = y >= 1 - cornerSize
        let isBottom = y <= cornerSize

        if isLeft && isTop { return .topLeft }
        if isRight && isTop { return .topRight }
        if isLeft && isBottom { return .bottomLeft }
        if isRight && isBottom { return .bottomRight }
        return nil
    }

    mutating func reset() {
        lastTap = nil
    }

    /// Call on finger lift when a touch stayed inside `corner` without sliding.
    mutating func registerLift(corner: CornerPosition, now: TimeInterval, duration: TimeInterval, travel: Double) -> Bool {
        if corner.isBottom {
            let sinceKey = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
            if sinceKey < bottomTypingCooldown {
                lastTap = nil
                return false
            }
        }

        guard duration <= maxDuration, travel < maxTravel else {
            lastTap = nil
            return false
        }

        if let previous = lastTap,
           previous.corner == corner,
           now - previous.time >= 0.04,
           now - previous.time <= maxInterval {
            lastTap = nil
            return true
        }

        lastTap = (corner, now)
        return false
    }
}

/// Filters accidental palm/wrist contacts and classifies trackpad edge zones.
struct PalmRejection {
    var edgeWidth: Float = 0.04
    var topEdgeHeight: Float = 0.06
    // Normal fingertip contacts on Apple Force Touch trackpads typically measure
    // majorAxis ~7–14, minorAxis ~5–11, total ~0.3–1.8. Palms/wrists exceed these.
    var maxMajorAxis: Float = 16.5
    var maxMinorAxis: Float = 13.0
    var maxTotal: Float = 2.0

    func isPalm(_ touch: OMSTouchData) -> Bool {
        let major = touch.axis.major
        let minor = touch.axis.minor
        let total = touch.total
        guard major.isFinite, minor.isFinite, total.isFinite else { return true }
        return major > maxMajorAxis || minor > maxMinorAxis || total > maxTotal
    }

    func edgeSide(x: Float, y: Float) -> EdgeSide? {
        if x <= edgeWidth { return .left }
        if x >= 1 - edgeWidth { return .right }
        if y >= 1 - topEdgeHeight { return .top }
        return nil
    }

    func isWithinDriftBounds(side: EdgeSide, x: Float, y: Float) -> Bool {
        switch side {
        case .left: return x <= edgeWidth + 0.02
        case .right: return x >= 1 - edgeWidth - 0.02
        case .top: return y >= 1 - topEdgeHeight - 0.03
        }
    }
}

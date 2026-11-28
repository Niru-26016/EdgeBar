import Foundation
import Observation

enum EdgeAction: String, CaseIterable, Identifiable {
    case none = "None"
    case volume = "Sound"
    case brightness = "Brightness"
    case keyboardBacklight = "Backlight"

    var id: String { rawValue }
}

enum CornerPosition: String, CaseIterable, Identifiable {
    case topLeft = "Top-Left"
    case topRight = "Top-Right"
    case bottomLeft = "Bottom-Left"
    case bottomRight = "Bottom-Right"

    var id: String { rawValue }

    var isBottom: Bool {
        self == .bottomLeft || self == .bottomRight
    }
}

enum CornerAction: String, CaseIterable, Identifiable {
    case none = "None"
    case mute = "Mute / Unmute"
    case playPause = "Play / Pause"
    case nextTrack = "Next Track"
    case previousTrack = "Previous Track"
    case missionControl = "Mission Control"
    case showDesktop = "Show Desktop"
    case lockScreen = "Lock Screen"
    case sleepDisplay = "Sleep Display"
    case toggleDarkMode = "Toggle Dark Mode"
    case screenshotArea = "Screenshot (Area)"
    case toggleDND = "Focus / DND (Shortcut)"

    var id: String { rawValue }
}

@MainActor
@Observable
final class EdgeBarSettings {
    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Keys.haptics) }
    }
    var leftEdgeAction: EdgeAction {
        didSet { UserDefaults.standard.set(leftEdgeAction.rawValue, forKey: Keys.leftEdge) }
    }
    var topEdgeAction: EdgeAction {
        didSet { UserDefaults.standard.set(topEdgeAction.rawValue, forKey: Keys.topEdge) }
    }
    var rightEdgeAction: EdgeAction {
        didSet { UserDefaults.standard.set(rightEdgeAction.rawValue, forKey: Keys.rightEdge) }
    }
    var topLeftAction: CornerAction {
        didSet { UserDefaults.standard.set(topLeftAction.rawValue, forKey: Keys.corner(.topLeft)) }
    }
    var topRightAction: CornerAction {
        didSet { UserDefaults.standard.set(topRightAction.rawValue, forKey: Keys.corner(.topRight)) }
    }
    var bottomLeftAction: CornerAction {
        didSet { UserDefaults.standard.set(bottomLeftAction.rawValue, forKey: Keys.corner(.bottomLeft)) }
    }
    var bottomRightAction: CornerAction {
        didSet { UserDefaults.standard.set(bottomRightAction.rawValue, forKey: Keys.corner(.bottomRight)) }
    }

    init() {
        let d = UserDefaults.standard
        hapticsEnabled = d.object(forKey: Keys.haptics) as? Bool ?? true
        leftEdgeAction = Self.loadEdge(Keys.leftEdge, fallback: .brightness)
        topEdgeAction = Self.loadEdge(Keys.topEdge, fallback: .keyboardBacklight)
        rightEdgeAction = Self.loadEdge(Keys.rightEdge, fallback: .volume)
        topLeftAction = Self.loadCorner(.topLeft, fallback: .none)
        topRightAction = Self.loadCorner(.topRight, fallback: .mute)
        bottomLeftAction = Self.loadCorner(.bottomLeft, fallback: .none)
        bottomRightAction = Self.loadCorner(.bottomRight, fallback: .none)
    }

    func action(for side: EdgeSide) -> EdgeAction {
        switch side {
        case .left: return leftEdgeAction
        case .top: return topEdgeAction
        case .right: return rightEdgeAction
        }
    }

    func action(for corner: CornerPosition) -> CornerAction {
        switch corner {
        case .topLeft: return topLeftAction
        case .topRight: return topRightAction
        case .bottomLeft: return bottomLeftAction
        case .bottomRight: return bottomRightAction
        }
    }

    private enum Keys {
        static let leftEdge = "edge.left"
        static let topEdge = "edge.top"
        static let rightEdge = "edge.right"
        static let haptics = "settings.haptics"
        static func corner(_ pos: CornerPosition) -> String { "corner.\(pos.rawValue)" }
    }

    private static func loadEdge(_ key: String, fallback: EdgeAction) -> EdgeAction {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let action = EdgeAction(rawValue: raw) else { return fallback }
        return action
    }

    private static func loadCorner(_ corner: CornerPosition, fallback: CornerAction) -> CornerAction {
        guard let raw = UserDefaults.standard.string(forKey: Keys.corner(corner)),
              let action = CornerAction(rawValue: raw) else { return fallback }
        return action
    }
}

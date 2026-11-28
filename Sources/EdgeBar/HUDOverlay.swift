import AppKit
import SwiftUI

enum HUDKind: Sendable {
    case display
    case volume
    case keyboard
}

@Observable
final class HUDState: @unchecked Sendable {
    var value: Double = 0.5
    var kind: HUDKind = .display
}

struct HUDView: View {
    var state: HUDState
    private let totalSegments = 16

    private var leftIcon: String {
        switch state.kind {
        case .display:
            return "sun.max.fill"
        case .keyboard:
            return state.value <= 0.001 ? "light.min" : "light.max"
        case .volume:
            if state.value <= 0.001 { return "speaker.slash.fill" }
            if state.value < 0.33 { return "speaker.wave.1.fill" }
            if state.value < 0.66 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: leftIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .contentTransition(.symbolEffect(.replace))

            HStack(spacing: 3.5) {
                ForEach(0..<totalSegments, id: \.self) { index in
                    let filled = state.value >= (Double(index) + 0.5) / Double(totalSegments)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(filled ? Color.white : Color.white.opacity(0.24))
                        .frame(width: 13, height: 7.5)
                        .animation(.easeOut(duration: 0.06), value: state.value)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .frame(width: 344, height: 54)
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.black.opacity(0.65))
            }
            .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.75))
        }
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 8)
    }
}

/// Fallback overlay shown while Accessibility permission is not yet granted for native MenuBarAgent OSD.
@MainActor
final class HUDOverlay {
    private let state = HUDState()
    private lazy var panel: NSPanel = makePanel()
    private var hideTask: Task<Void, Never>?

    func showBrightness(_ value: Double) {
        show(kind: .display, value: value)
    }

    func showVolume(_ value: Double) {
        show(kind: .volume, value: value)
    }

    func showKeyboardBrightness(_ value: Double) {
        show(kind: .keyboard, value: value)
    }

    private func show(kind: HUDKind, value: Double) {
        state.kind = kind
        state.value = max(0, min(1, value))
        present()
    }

    private func present() {
        hideTask?.cancel()
        reposition()
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()
        scheduleHide()
    }

    private func makePanel() -> NSPanel {
        let hostingView = NSHostingView(rootView: HUDView(state: state))
        let size = CGSize(width: 344, height: 54)
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.hidesOnDeactivate = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.contentView = hostingView
        return p
    }

    private func reposition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = CGSize(width: 344, height: 54)
        let vf = screen.visibleFrame
        let x = vf.maxX - size.width - 16
        let y = vf.maxY - size.height - 12
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled, let self else { return }
            let targetPanel = self.panel
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                targetPanel.animator().alphaValue = 0.0
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.panel.alphaValue == 0.0 else { return }
                    self.panel.orderOut(nil)
                }
            }
        }
    }
}

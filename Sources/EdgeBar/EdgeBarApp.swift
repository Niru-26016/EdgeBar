import AppKit
import SwiftUI

@main
struct EdgeBarApp: App {
    private let model = EdgeBarModel()

    var body: some Scene {
        MenuBarExtra("EdgeBar", systemImage: "slider.vertical.3") {
            EdgeBarMenu(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct EdgeBarMenu: View {
    @Bindable var model: EdgeBarModel
    @Bindable var settings: EdgeBarSettings

    init(model: EdgeBarModel) {
        self.model = model
        self.settings = model.settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "slider.vertical.3")
                Text("EdgeBar").font(.headline)
                Spacer()
                Circle().fill(model.isListening ? .green : .secondary).frame(width: 8, height: 8)
            }

            Text(model.status).font(.caption).foregroundStyle(.secondary)

            if !model.hasSystemHUD {
                Button("Enable Native macOS Bar…") {
                    model.requestSystemHUD()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()
            Text("Edge Sliders").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            EdgePickerRow(label: "Left edge", selection: $settings.leftEdgeAction, pct: model.levelPercent(for: settings.leftEdgeAction))
            EdgePickerRow(label: "Top edge", selection: $settings.topEdgeAction, pct: model.levelPercent(for: settings.topEdgeAction))
            EdgePickerRow(label: "Right edge", selection: $settings.rightEdgeAction, pct: model.levelPercent(for: settings.rightEdgeAction))

            Divider()
            Text("Corner Double-Tap").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            CornerPickerRow(label: "Top-left", selection: $settings.topLeftAction)
            CornerPickerRow(label: "Top-right", selection: $settings.topRightAction)
            CornerPickerRow(label: "Bottom-left", selection: $settings.bottomLeftAction)
            CornerPickerRow(label: "Bottom-right", selection: $settings.bottomRightAction)

            Divider()
            Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
                .font(.caption)
            HStack {
                Text("Palm rejection & cursor freeze on")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .font(.caption2)
        }
        .padding(14)
        .frame(width: 300)
        .onAppear {
            model.syncSystemLevels()
        }
    }
}

private struct EdgePickerRow: View {
    let label: String
    @Binding var selection: EdgeAction
    let pct: String?

    var body: some View {
        HStack {
            Text(label).font(.caption)
            if let pct {
                Text(pct).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            Picker("", selection: $selection) {
                ForEach(EdgeAction.allCases) { action in
                    Text(action.rawValue).tag(action)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 122)
        }
    }
}

private struct CornerPickerRow: View {
    let label: String
    @Binding var selection: CornerAction

    var body: some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(CornerAction.allCases) { action in
                    Text(action.rawValue).tag(action)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 162)
        }
    }
}

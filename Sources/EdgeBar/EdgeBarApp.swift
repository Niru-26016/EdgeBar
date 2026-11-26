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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            HStack {
                Label("Left edge · Brightness", systemImage: "sun.max")
                Spacer()
                Text("\(Int((model.brightnessPreview * 100).rounded()))%")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            HStack {
                Label("Right edge · Volume", systemImage: "speaker.wave.2")
                Spacer()
                Text("\(Int((model.volumePreview * 100).rounded()))%")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Divider()
            Toggle("Haptic feedback", isOn: $model.hapticsEnabled)
            HStack {
                Text("Edge zone: 4%")
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 240)
        .onAppear {
            model.syncSystemLevels()
        }
    }
}

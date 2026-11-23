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

            Divider()
            Label("Left edge · Brightness", systemImage: "sun.max")
                .font(.subheadline)
            Slider(value: $model.brightnessPreview, in: 0...1) { editing in
                if !editing { model.setBrightness(model.brightnessPreview) }
            }

            Label("Right edge · Volume", systemImage: "speaker.wave.2")
                .font(.subheadline)
            Slider(value: $model.volumePreview, in: 0...1) { editing in
                if !editing { model.setVolume(model.volumePreview) }
            }

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
        .frame(width: 280)
    }
}

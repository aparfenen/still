import SwiftUI
import AppKit

@main
@MainActor
struct StillApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Still", id: "library") {
            LibraryView().environmentObject(model)
                .frame(minWidth: 840, minHeight: 560)
                .onAppear { NSApplication.shared.setActivationPolicy(.regular) }
        }
        .defaultSize(width: 1080, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Save to Still…") { model.showCapture = true }
                    .keyboardShortcut("n")
            }
            CommandMenu("Library") {
                Button("Export Library…") { model.exportLibrary() }
                Button("Import Library…") { model.importLibrary() }
                Divider()
                Toggle("Automatic Clipboard Capture", isOn: $model.captureEnabled)
                Button("Capture Preferences…") { model.showPreferences = true }
            }
        }

        MenuBarExtra("Still", systemImage: "heart") {
            MenuBarView().environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Settings { PreferencesView().environmentObject(model) }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Still").font(.headline)
            Button("Save to Still…") {
                openWindow(id: "library")
                NSApp.activate(ignoringOtherApps: true)
                model.showCapture = true
            }
            Button("Open Library") {
                openWindow(id: "library")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Toggle("Automatic capture", isOn: $model.captureEnabled)
                .disabled(!model.isAvailable)
            Text(model.captureEnabled ? "Capturing links and text" : "Capture paused")
                .font(.caption).foregroundStyle(.secondary)
            Button("Preferences…") {
                openWindow(id: "library")
                NSApp.activate(ignoringOtherApps: true)
                model.showPreferences = true
            }
            Divider()
            Button("Quit Still") { NSApp.terminate(nil) }
        }
        .padding(20).frame(width: 260)
    }
}

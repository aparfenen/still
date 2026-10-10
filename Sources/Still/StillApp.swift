import SwiftUI
import AppKit
import StillCore
typealias ViewState<Value> = SwiftUI.State<Value>

@main
@MainActor
struct StillApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Still", id: "library") {
            LibraryView().environmentObject(model)
                .frame(minWidth: 1060, minHeight: 560)
                .onAppear { NSApplication.shared.setActivationPolicy(.regular) }
        }
        .defaultSize(width: 1180, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Save to Still…") { model.showCapture = true }
                    .keyboardShortcut("n")
            }
            CommandMenu("Library") {
                Menu("Export Library") {
                    ForEach(LibraryExportFormat.allCases) { format in
                        Button(format.label) { model.exportLibrary(format: format) }
                    }
                }
                Button("Manage Folders…") { model.showOrganization = true }
                Button("Import Library…") { model.importLibrary() }
                Divider()
                Toggle("Automatic Clipboard Capture", isOn: $model.captureEnabled)
                Button("Capture Preferences…") { model.showPreferences = true }
            }
        }

        MenuBarExtra("Still", systemImage: "bookmark.fill") {
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
            StillHeader()
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

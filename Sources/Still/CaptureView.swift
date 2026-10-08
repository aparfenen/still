import SwiftUI
import AppKit

struct CaptureView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save to Still").font(.title2.weight(.medium))
            TextField("Optional title", text: $title)
            TextEditor(text: $text).font(.body)
                .frame(height: 180).border(Color.secondary.opacity(0.2))
                .accessibilityLabel("Link or text to save")
            HStack {
                Button("Paste clipboard") { text = NSPasteboard.general.string(forType: .string) ?? "" }
                Spacer()
                Text("On this Mac").font(.caption).foregroundStyle(.secondary)
            }
            Text("Manual saves stay until you delete them.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if model.capture(text, title: title) { dismiss() }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.isAvailable)
            }
            if let message = model.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }.padding(24).frame(width: 450).background(Palette.paper)
    }
}

struct PreferencesView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("retentionDays") private var retentionDays = 7
    @AppStorage("excludedApps") private var excludedApps = AppModel.excludedDefaults

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Capture & privacy").font(.title2)
            Toggle("Automatically capture links and plain text", isOn: $model.captureEnabled)
                .disabled(!model.isAvailable)
            Text("Off by default. Capture works only while Still is running. Sensitive clipboard markers are respected, but not every secret can be detected.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Temporary history", selection: $retentionDays) {
                Text("1 day").tag(1)
                Text("7 days").tag(7)
                Text("30 days").tag(30)
            }.onChange(of: retentionDays) { _, _ in model.pruneNow() }
            Text("Manual saves, kept items, and annotations do not expire. Shortening retention removes expired temporary items.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Excluded apps").font(.headline)
            Text("One bundle identifier per line. Source detection is approximate; exclusions are not a security guarantee.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $excludedApps).font(.system(.caption, design: .monospaced))
                .frame(height: 130).border(Color.secondary.opacity(0.2))
                .accessibilityLabel("Excluded application bundle identifiers")
            Divider()
            HStack {
                Button("Export library…") { model.exportLibrary() }
                Button("Import library…") { model.importLibrary() }
                Spacer()
                Button("Done") { model.showPreferences = false }
            }
            Text("Library: ~/Library/Application Support/Still/ · Local only; no iCloud or analytics.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 520)
    }
}

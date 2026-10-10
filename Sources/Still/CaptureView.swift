import SwiftUI
import AppKit

struct CaptureView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ViewState private var text = ""
    @ViewState private var title = ""

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
    @Environment(\.dismiss) private var dismiss
    @AppStorage("retentionDays") private var retentionDays = 7
    @AppStorage("excludedApps") private var excludedApps = AppModel.excludedDefaults
    @AppStorage("readerFont") private var readerFont = ReaderDefaults.font
    @AppStorage("readerSize") private var readerSize = ReaderDefaults.size
    @AppStorage("readerSpacing") private var readerSpacing = ReaderDefaults.spacing
    @AppStorage("readerInset") private var readerInset = ReaderDefaults.inset
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StillHeader()
            TabView {
                reading.tabItem { Label("Reading", systemImage: "textformat") }
                capture.tabItem { Label("Capture", systemImage: "doc.on.clipboard") }
            }.frame(height: 450)
            HStack {
                Spacer()
                Button("Done") { model.showPreferences = false; dismiss() }
            }
        }.padding(24).frame(width: 540).background(Palette.paper)
    }

    private var reading: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Font", selection: $readerFont) {
                Text("System").tag("system")
                Text("Georgia serif").tag("serif")
                Text("Rounded").tag("rounded")
                Text("Monospaced").tag("mono")
            }
            settingSlider("Font size", value: $readerSize, range: 12...32)
            settingSlider("Line spacing", value: $readerSpacing, range: 0...20)
            settingSlider("Reading margins", value: $readerInset, range: 12...96)
            Picker("Appearance", selection: $appearance) {
                Text("Follow system").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Text("Reading settings update the reader immediately and stay on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Reset reading settings") {
                readerFont = ReaderDefaults.font; readerSize = ReaderDefaults.size
                readerSpacing = ReaderDefaults.spacing; readerInset = ReaderDefaults.inset
                appearance = "system"
            }
            Spacer()
        }.padding(20)
    }

    private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue)) pt").foregroundStyle(.secondary) }
            Slider(value: value, in: range, step: 1).accessibilityLabel(title)
        }
    }

    private var capture: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Automatically capture links and plain text", isOn: $model.captureEnabled)
                .disabled(!model.isAvailable)
            Text("Off by default. Capture works while Still runs. Sensitive markers are respected, but not every secret is detected.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Temporary history", selection: $retentionDays) {
                Text("1 day").tag(1); Text("7 days").tag(7); Text("30 days").tag(30)
            }.onChange(of: retentionDays) { _, _ in model.pruneNow() }
            Text("Manual, kept, annotated, and organized items do not expire. Shortening retention removes expired temporary items.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Excluded apps").font(.headline)
            Text("One bundle identifier per line. Source detection is approximate.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $excludedApps).font(.system(.caption, design: .monospaced))
                .frame(height: 95).border(Color.secondary.opacity(0.2))
                .accessibilityLabel("Excluded application bundle identifiers")
            HStack {
                Button("JSON backup…") { model.exportLibrary() }
                Button("Import backup…") { model.importLibrary() }
            }
            Text("Local only · No iCloud or analytics").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding(20)
    }
}

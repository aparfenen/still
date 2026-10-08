import SwiftUI
import AppKit
import StillCore

enum LibraryFilter: String, CaseIterable {
    case inbox = "Inbox", unread = "Unread", kept = "Kept", finished = "Finished"
    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .unread: return "circle"
        case .kept: return "heart"
        case .finished: return "checkmark.circle"
        }
    }
    func includes(_ item: LibraryItem) -> Bool {
        switch self {
        case .inbox: return true
        case .unread: return item.status != .finished
        case .kept: return item.isKept
        case .finished: return item.status == .finished
        }
    }
}

enum Palette {
    static let paper = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.13, alpha: 1)
            : NSColor(red: 0.98, green: 0.975, blue: 0.96, alpha: 1)
    })
}

struct LibraryView: View {
    @EnvironmentObject var model: AppModel
    @State private var filter: LibraryFilter = .inbox
    @State private var source = ""
    @State private var recentOnly = false
    @State private var deleteCandidate: LibraryItem?
    @FocusState private var searching: Bool

    private var visible: [LibraryItem] {
        model.matches.filter {
            filter.includes($0) && (source.isEmpty || $0.sourceApp == source)
                && (!recentOnly || $0.createdAt >= Date().addingTimeInterval(-7 * 86400))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            navigation
            Divider()
            VStack(spacing: 0) {
                searchBar
                Divider()
                HStack {
                    Menu {
                        Button("All apps") { source = "" }
                        ForEach(model.sources, id: \.self) { name in
                            Button(name) { source = name }
                        }
                    } label: { Label(source.isEmpty ? "All apps" : source, systemImage: "app") }
                    Spacer()
                    Menu {
                        Button("Any date") { recentOnly = false }
                        Button("Last 7 days") { recentOnly = true }
                    } label: { Text(recentOnly ? "Last 7 days" : "Any date") }
                }
                .font(.caption).padding(12)
                .menuStyle(.borderlessButton)
                List(selection: $model.selectedID) {
                    ForEach(visible) { item in
                        row(item).tag(item.id)
                            .contextMenu {
                                Button(item.isKept ? "Unkeep" : "Keep") {
                                    var value = item; value.isKept.toggle(); model.update(value)
                                }
                                Button("Copy original") { model.copyOriginal(item) }
                                Divider()
                                Button("Delete…", role: .destructive) { deleteCandidate = item }
                            }
                    }
                }
                .listStyle(.plain)
                if visible.isEmpty && !model.items.isEmpty {
                    Text("No matching items").font(.caption).foregroundStyle(.secondary).padding()
                }
                Divider()
                Button {
                    model.showPreferences = true
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(model.captureEnabled ? Color.green : Color.secondary).frame(width: 6, height: 6)
                        Text(model.captureEnabled ? "Capture on" : "Capture paused")
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                    }.font(.caption).foregroundStyle(.secondary)
                }.buttonStyle(.plain).padding(12)
            }
            .frame(width: 282)
            Divider()
            if let item = model.selected {
                ReaderView(item: item).id(item.id).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.paper)
        .toolbar {
            ToolbarItem {
                Button { model.showCapture = true } label: { Label("Save to Still", systemImage: "plus") }
                    .disabled(!model.isAvailable)
            }
        }
        .sheet(isPresented: $model.showCapture) { CaptureView().environmentObject(model) }
        .sheet(isPresented: $model.showPreferences) { PreferencesView().environmentObject(model) }
        .alert("Still needs your attention", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("Delete this item?", isPresented: Binding(
            get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
            Button("Delete", role: .destructive) {
                if let item = deleteCandidate { model.delete(item) }
                deleteCandidate = nil
            }
        } message: { Text("Its saved text, highlights, and comments will be removed from this Mac.") }
        .onChange(of: model.query) { _, _ in model.reload() }
        .onChange(of: model.selectedID) { _, _ in
            if var selected = model.selected, selected.status == .unread {
                selected.status = .reading
                model.update(selected)
            }
        }
    }

    private var navigation: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart").font(.system(size: 20, weight: .light))
                .padding(.top, 22).padding(.bottom, 20).accessibilityLabel("Still")
            ForEach(LibraryFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                    // Keep selection consistent with the navigation filter.
                    if let selected = model.selected, !option.includes(selected) { model.selectedID = nil }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: option.icon).font(.system(size: 17))
                        Text(option.rawValue).font(.system(size: 10))
                        Text("\(model.items.filter(option.includes).count)")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .frame(width: 58, height: 64)
                    .background(filter == option ? Color.primary.opacity(0.07) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.rawValue), \(model.items.filter(option.includes).count) items")
                .accessibilityAddTraits(filter == option ? .isSelected : [])
            }
            Spacer()
            Button { model.exportLibrary() } label: {
                Image(systemName: "square.and.arrow.up")
            }.buttonStyle(.plain).help("Export library").padding(.bottom, 20)
        }
        .frame(width: 76)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search your library", text: $model.query).textFieldStyle(.plain).focused($searching)
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }.padding(14)
    }

    private func row(_ item: LibraryItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if item.status == .unread { Circle().fill(Color.secondary).frame(width: 5, height: 5) }
                Text(item.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                if item.isKept { Image(systemName: "heart.fill").font(.caption).accessibilityLabel("Kept") }
            }
            HStack(spacing: 4) {
                Text(item.sourceApp.map { "Likely \($0)" } ?? (item.url == nil ? "Text" : "Link")).lineLimit(1)
                Text("·")
                Text(item.createdAt, format: .dateTime.month(.abbreviated).day())
            }.font(.system(size: 10)).foregroundStyle(.secondary)
            if let expiry = item.expiresAt(retentionDays: UserDefaults.standard.integer(forKey: "retentionDays")) {
                Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(.secondary)
            Text(model.items.isEmpty ? "A place for things worth keeping." : "Return to something useful.")
                .font(.system(size: 22, weight: .regular, design: .serif))
            Text(model.items.isEmpty ? "Paste a link or a passage. Your library stays on this Mac." : "Choose an item from your library.")
                .font(.callout).foregroundStyle(.secondary)
            if model.items.isEmpty {
                Button("Save something") { model.showCapture = true }
                    .buttonStyle(.borderedProminent).tint(.primary).disabled(!model.isAvailable)
                Text("Automatic capture is \(model.captureEnabled ? "on" : "off").")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(32)
    }
}

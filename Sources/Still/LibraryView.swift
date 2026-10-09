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
    func includes(_ item: StillCore.LibraryItem) -> Bool {
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
    @AppStorage("appearance") private var appearance = "system"
    @State private var filter: LibraryFilter = .inbox
    @State private var source = ""
    @State private var folderID: UUID?
    @State private var tag = ""
    @State private var category = ""
    @State private var organizingID: UUID?
    @State private var recentOnly = false
    @State private var deleteCandidate: StillCore.LibraryItem?
    @FocusState private var searching: Bool

    private var visible: [StillCore.LibraryItem] {
        model.matches.filter {
            filter.includes($0) && (source.isEmpty || $0.sourceApp == source)
                && (folderID == nil || $0.folderID == folderID)
                && (tag.isEmpty || ($0.tags ?? []).contains(tag))
                && (category.isEmpty || $0.category == category)
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
                                Button("Organize…") { organizingID = item.id }
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
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .toolbar {
            ToolbarItem(placement: .principal) { StillHeader() }
            ToolbarItem {
                Button { model.showCapture = true } label: { Label("Save to Still", systemImage: "plus") }
                    .disabled(!model.isAvailable)
            }
        }
        .sheet(isPresented: $model.showOrganization) { OrganizationView().environmentObject(model) }
        .sheet(isPresented: Binding(get: { organizingID != nil }, set: { if !$0 { organizingID = nil } })) {
            if let id = organizingID { ItemOrganizationView(itemID: id).environmentObject(model) }
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

    private var allTags: [String] { Array(Set(model.items.flatMap { $0.tags ?? [] })).sorted() }
    private var categories: [String] { Array(Set(model.items.compactMap(\.category).filter { !$0.isEmpty })).sorted() }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(LibraryFilter.allCases, id: \.self) { option in
                        sidebarButton(option.rawValue + "  \(model.items.filter(option.includes).count)", icon: option.icon,
                                      selected: filter == option && folderID == nil && tag.isEmpty && category.isEmpty) {
                            filter = option; folderID = nil; tag = ""; category = ""
                            model.selectedID = nil
                        }
                    }
                    Divider().padding(.vertical, 8)
                    HStack {
                        Text("FOLDERS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Button { model.showOrganization = true } label: { Image(systemName: "plus") }
                            .buttonStyle(.plain).accessibilityLabel("Manage folders")
                    }.padding(.horizontal, 10)
                    ForEach(model.folders) { folder in
                        sidebarButton(folder.name, icon: "folder", selected: folderID == folder.id) {
                            folderID = folder.id; filter = .inbox; tag = ""; category = ""; model.selectedID = nil
                        }
                    }
                    if model.folders.isEmpty {
                        Button("Create folder…") { model.showOrganization = true }.buttonStyle(.plain)
                            .font(.caption).padding(10)
                    }
                    if !allTags.isEmpty {
                        Divider().padding(.vertical, 8)
                        Text("TAGS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 10)
                        ForEach(allTags, id: \.self) { name in
                            sidebarButton(name, icon: "number", selected: tag == name) {
                                tag = name; category = ""; folderID = nil; filter = .inbox; model.selectedID = nil
                            }
                        }
                    }
                    if !categories.isEmpty {
                        Divider().padding(.vertical, 8)
                        Text("CATEGORIES").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 10)
                        ForEach(categories, id: \.self) { name in
                            sidebarButton(name, icon: "square.grid.2x2", selected: category == name) {
                                category = name; tag = ""; folderID = nil; filter = .inbox; model.selectedID = nil
                            }
                        }
                    }
                }.padding(.top, 16)
            }
            Divider()
            Menu {
                ForEach(LibraryExportFormat.allCases) { format in
                    Button(format.label) { model.exportLibrary(format: format) }
                }
            } label: { Label("Export library", systemImage: "square.and.arrow.up") }
                .menuStyle(.borderlessButton).font(.caption).padding(10)
            Button { model.showPreferences = true } label: { Label("Settings", systemImage: "gearshape") }
                .buttonStyle(.plain).font(.caption).padding(.horizontal, 10).padding(.bottom, 12)
        }.padding(.horizontal, 8).frame(width: 174)
    }

    private func sidebarButton(_ title: String, icon: String, selected: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 18).foregroundStyle(selected ? Brand.lavender : Color.secondary)
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
            }.font(.system(size: 12)).padding(.horizontal, 10).padding(.vertical, 8)
                .background(selected ? Brand.lavender.opacity(0.14) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
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

    private func row(_ item: StillCore.LibraryItem) -> some View {
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
            BookmarkMark().fill(Brand.lavender).frame(width: 28, height: 38)
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

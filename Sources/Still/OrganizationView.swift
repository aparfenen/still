import SwiftUI
import StillCore

struct OrganizationView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var editingID: UUID?
    @State private var deleting: LibraryFolder?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StillHeader()
            Text("Folders").font(.title2)
            List(model.folders) { folder in
                HStack {
                    Label(folder.name, systemImage: "folder")
                    Spacer()
                    Button("Rename") { editingID = folder.id; name = folder.name }
                    Button(role: .destructive) { deleting = folder } label: {
                        Image(systemName: "trash")
                    }.accessibilityLabel("Delete folder " + folder.name)
                }
            }.frame(height: 230)
            HStack {
                TextField(editingID == nil ? "New folder name" : "Folder name", text: $name)
                Button(editingID == nil ? "Create" : "Save") {
                    model.errorMessage = nil
                    model.saveFolder(name: name, id: editingID)
                    if model.errorMessage == nil { name = ""; editingID = nil }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if editingID != nil { Button("Cancel") { editingID = nil; name = "" } }
            }
            if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
            Text("Folders group items. Tags and a category can be edited through Organize in the reader.")
                .font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Done") { dismiss() } }
        }.padding(24).frame(width: 480).background(Palette.paper)
        .alert("Delete folder?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete folder", role: .destructive) {
                if let folder = deleting { model.deleteFolder(folder) }
                deleting = nil
            }
        } message: { Text("Its items stay in your library and are marked Keep. No saved content is deleted.") }
    }
}

struct ItemOrganizationView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var folderID: UUID?
    @State private var tags = ""
    @State private var category = ""
    @State private var newFolder = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Organize").font(.title2)
            Picker("Folder", selection: $folderID) {
                Text("No folder").tag(Optional<UUID>.none)
                ForEach(model.folders) { folder in Text(folder.name).tag(Optional(folder.id)) }
            }
            HStack {
                TextField("Create a folder", text: $newFolder)
                Button("Create") {
                    model.errorMessage = nil
                    model.saveFolder(name: newFolder)
                    if model.errorMessage == nil {
                        folderID = model.folders.first { $0.name == newFolder.trimmingCharacters(in: .whitespacesAndNewlines) }?.id
                        newFolder = ""
                    }
                }.disabled(newFolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            TextField("Category, e.g. Design or Research", text: $category)
            TextField("Tags, separated by commas", text: $tags)
            Text("One folder, one category, as many useful tags as you need. Organized items do not expire.")
                .font(.caption).foregroundStyle(.secondary)
            if let message = model.errorMessage { Text(message).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    guard var item = model.items.first(where: { $0.id == itemID }) else { return }
                    let parsed = Organization.normalizedTags(tags)
                    guard parsed.count <= 100, category.count <= 80 else {
                        model.errorMessage = "Use up to 100 tags and a category no longer than 80 characters."
                        return
                    }
                    item.folderID = folderID
                    item.tags = parsed
                    item.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Removing organization later does not unexpectedly reactivate expiry.
                    if folderID != nil || !parsed.isEmpty || !(item.category ?? "").isEmpty { item.isKept = true }
                    model.errorMessage = nil
                    model.update(item)
                    if model.errorMessage == nil { dismiss() }
                }.keyboardShortcut(.return, modifiers: .command)
            }
        }.padding(24).frame(width: 460).background(Palette.paper)
        .onAppear {
            guard let item = model.items.first(where: { $0.id == itemID }) else { return }
            folderID = item.folderID; category = item.category ?? ""; tags = (item.tags ?? []).joined(separator: ", ")
        }
    }
}

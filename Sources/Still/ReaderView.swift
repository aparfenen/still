import SwiftUI
import AppKit
import StillCore

struct ReaderView: View {
    @EnvironmentObject var model: AppModel
    let item: LibraryItem
    @State private var selection = NSRange(location: NSNotFound, length: 0)
    @State private var showNotes = false
    @State private var editing: Annotation?
    @State private var sharing: Annotation?
    @State private var deleting: Annotation?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title).font(.system(size: 23, weight: .regular, design: .serif)).lineLimit(2)
                    Text("\(item.url?.host ?? "Saved text") · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                    if let date = item.snapshotAt {
                        Text("Offline snapshot · \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    var value = item; value.isKept.toggle(); model.update(value)
                } label: {
                    Label(item.isKept ? "Kept" : "Keep", systemImage: item.isKept ? "heart.fill" : "heart")
                }.help("Kept items do not expire")
                Button { model.copyOriginal(item) } label: { Image(systemName: "doc.on.doc") }
                    .help("Copy original").accessibilityLabel("Copy original")
                ShareLink(item: item.original) { Image(systemName: "square.and.arrow.up") }
                    .help("Share original").accessibilityLabel("Share original")
            }.padding(24)
            HStack(spacing: 14) {
                Button {
                    model.addAnnotation(item: item, range: selection)
                    showNotes = true
                } label: { Label("Highlight", systemImage: "highlighter") }
                    .disabled(selection.location == NSNotFound || selection.length == 0)
                Button {
                    showNotes.toggle()
                } label: { Label("\(item.annotations.count) notes", systemImage: "text.bubble") }
                Spacer()
                Picker("Reading status", selection: Binding(
                    get: { item.status },
                    set: { status in var value = item; value.status = status; model.update(value) }
                )) {
                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                        Text(status.rawValue.capitalized).tag(status)
                    }
                }.labelsHidden().frame(width: 115)
            }.font(.caption).padding(.horizontal, 24).padding(.bottom, 14)
            Divider()
            if item.url != nil && item.articleText == nil {
                HStack {
                    Text("Save readable text for offline use. Some sites aren't supported.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(model.isPreparing ? "Preparing…" : "Prepare reader") { model.prepareReader(item) }
                        .disabled(model.isPreparing)
                }.padding(16)
                Divider()
            }
            NativeReader(item: item, selection: $selection) { offset in
                model.savePosition(id: item.id, offset: offset)
            }
            if showNotes {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if item.annotations.isEmpty {
                            Text("Select words in the reader, then choose Highlight.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(item.annotations) { note in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("“\(note.quote)”").font(.system(.callout, design: .serif)).lineLimit(3)
                                if !note.comment.isEmpty { Text(note.comment).font(.callout) }
                                HStack {
                                    Text(note.modifiedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.caption2).foregroundStyle(.secondary)
                                    if note.resolvedRange(in: item.readingText) == nil {
                                        Text("Passage moved").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Comment") { editing = note }
                                    Button("Share") { sharing = note }
                                    Button(role: .destructive) { deleting = note } label: {
                                        Image(systemName: "trash")
                                    }.accessibilityLabel("Delete annotation")
                                }.font(.caption)
                            }.padding(12).background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding(16)
                }.frame(maxHeight: 220)
            }
            Divider()
            HStack {
                if item.url != nil { Button("Open original") { model.openOriginal(item) } }
                Spacer()
                Text(item.isPermanent ? "Saved on this Mac" : "Temporary history")
                    .font(.caption).foregroundStyle(.secondary)
                if item.status != .finished {
                    Button("Mark finished") { var value = item; value.status = .finished; model.update(value) }
                }
            }.padding(14)
        }
        .background(Palette.paper)
        .sheet(item: $editing) { note in
            CommentView(itemID: item.id, annotation: note).environmentObject(model)
        }
        .sheet(item: $sharing) { note in SharePreview(item: item, annotation: note) }
        .alert("Delete this annotation?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) {
                if let note = deleting {
                    var value = item
                    value.annotations.removeAll { $0.id == note.id }
                    model.update(value)
                }
                deleting = nil
            }
        } message: { Text("The highlight and its comment will be removed.") }
    }
}

private struct CommentView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    let annotation: Annotation
    @State private var comment = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Comment").font(.title2)
            Text("“\(annotation.quote)”").font(.system(.body, design: .serif)).lineLimit(4)
            TextEditor(text: $comment).frame(height: 140).border(Color.secondary.opacity(0.2))
                .accessibilityLabel("Comment")
            Text("Created \(annotation.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            Text("Edited \(annotation.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save comment") {
                    guard var item = model.items.first(where: { $0.id == itemID }),
                          let index = item.annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
                    item.annotations[index].comment = comment
                    item.annotations[index].modifiedAt = Date()
                    model.update(item)
                    if model.errorMessage == nil { dismiss() }
                }.keyboardShortcut(.return, modifiers: .command)
            }
        }.padding(24).frame(width: 430).background(Palette.paper)
            .onAppear { comment = annotation.comment }
    }
}

private struct SharePreview: View {
    @Environment(\.dismiss) private var dismiss
    let item: LibraryItem
    let annotation: Annotation
    @State private var includeComment = false

    private var sharedText: String {
        var result = "“\(annotation.quote)”\n\n— \(item.title)"
        if let url = item.url { result += "\n" + url.absoluteString }
        if includeComment && !annotation.comment.isEmpty { result += "\n\n" + annotation.comment }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share excerpt").font(.title2)
            Text(sharedText).textSelection(.enabled).frame(maxHeight: 200, alignment: .topLeading)
            if !annotation.comment.isEmpty { Toggle("Include my comment", isOn: $includeComment) }
            Text("Only this excerpt, attribution, and any selected comment will be shared.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                ShareLink(item: sharedText) { Label("Share…", systemImage: "square.and.arrow.up") }
            }
        }.padding(24).frame(width: 430).background(Palette.paper)
    }
}

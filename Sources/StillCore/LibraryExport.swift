import Foundation

public enum LibraryExportFormat: String, CaseIterable, Identifiable, Sendable {
    case json, markdown, csv, text, html
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .json: return "JSON backup"
        case .markdown: return "Markdown"
        case .csv: return "CSV spreadsheet"
        case .text: return "Plain text"
        case .html: return "HTML document"
        }
    }
    public var fileExtension: String {
        switch self { case .markdown: return "md"; case .text: return "txt"; default: return rawValue }
    }
}

public enum LibraryExport {
    public static func data(items: [LibraryItem], folders: [LibraryFolder],
                            format: LibraryExportFormat) throws -> Data {
        if format == .json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(LibraryArchive(items: items, folders: folders))
        }
        func folder(_ item: LibraryItem) -> String { folders.first { $0.id == item.folderID }?.name ?? "" }
        func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
        let output: String
        switch format {
        case .json: fatalError("Handled above")
        case .csv:
            let header = ["Title", "Original", "Reader text", "Folder", "Category", "Tags", "Status", "Created", "Comments"]
            let rows = items.map { item in
                [item.title, item.original, item.readingText, folder(item), item.category ?? "",
                 (item.tags ?? []).joined(separator: ", "), item.status.rawValue, stamp(item.createdAt),
                 item.annotations.map { $0.quote + " — " + $0.comment + " [" + stamp($0.modifiedAt) + "]" }.joined(separator: "\n")]
            }
            output = ([header] + rows).map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\r\n")
        case .markdown, .text:
            let markdown = format == .markdown
            output = items.map { item in
                var blocks = [(markdown ? "# " : "") + item.title,
                    "Saved: " + stamp(item.createdAt),
                    "Folder: " + folder(item) + " · Category: " + (item.category ?? ""),
                    "Tags: " + (item.tags ?? []).joined(separator: ", "),
                    "Original: " + item.original,
                    item.articleText ?? ""]
                for note in item.annotations {
                    blocks.append((markdown ? "> " : "Highlight: ") + note.quote)
                    blocks.append(note.comment)
                    blocks.append("Created: " + stamp(note.createdAt) + " · Edited: " + stamp(note.modifiedAt))
                }
                return blocks.filter { !$0.isEmpty }.joined(separator: "\n\n")
            }.joined(separator: "\n\n---\n\n")
        case .html:
            let sections = items.map { item in
                let notes = item.annotations.map {
                    "<blockquote>" + html($0.quote) + "</blockquote><p>" + html($0.comment)
                    + "</p><small>Created " + stamp($0.createdAt) + " · Edited " + stamp($0.modifiedAt) + "</small>"
                }.joined()
                return "<article><h1>" + html(item.title) + "</h1><p>"
                    + html(folder(item) + " · " + (item.category ?? "") + " · " + (item.tags ?? []).joined(separator: ", "))
                    + "</p><small>Saved " + stamp(item.createdAt) + "</small><h2>Original</h2><pre>"
                    + html(item.original) + "</pre><h2>Reading text</h2><pre>" + html(item.readingText)
                    + "</pre>" + notes + "</article>"
            }.joined()
            output = """
            <!doctype html><html lang="en"><meta charset="utf-8"><title>Still library</title>
            <style>body{font:16px/1.65 system-ui;max-width:760px;margin:40px auto;padding:20px;color:#29272d}
            article{border-bottom:1px solid #ddd;padding:20px 0}pre{white-space:pre-wrap;font:inherit}
            blockquote{border-left:3px solid #b5a1dc;padding-left:16px;margin-left:0}small{color:#666}</style>
            <body>\(sections)</body></html>
            """
        }
        return Data(output.utf8)
    }

    private static func html(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func csvField(_ text: String) -> String {
        let leading = text.trimmingCharacters(in: .whitespacesAndNewlines).first
        let safe = leading.map { "=+-@".contains($0) } == true ? "'" + text : text
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

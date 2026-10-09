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
        let output: String
        switch format {
        case .json:
            throw StoreError(message: "Use JSON backup export.")
        case .csv:
            var rows: [[String]] = [
                ["Title", "Original", "Reader text", "Folder", "Category", "Tags", "Status", "Created", "Comments"]
            ]
            for item in items {
                var row: [String] = [item.title, item.original, item.readingText]
                row.append(folderName(item, folders: folders))
                row.append(item.category ?? "")
                row.append((item.tags ?? []).joined(separator: ", "))
                row.append(item.status.rawValue)
                row.append(stamp(item.createdAt))
                let comments = item.annotations.map { note -> String in
                    [note.quote, note.comment, "[" + stamp(note.modifiedAt) + "]"].joined(separator: " — ")
                }
                row.append(comments.joined(separator: "\n"))
                rows.append(row)
            }
            output = rows.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\r\n")
        case .markdown, .text:
            output = items.map { textSection($0, folders: folders, markdown: format == .markdown) }
                .joined(separator: "\n\n---\n\n")
        case .html:
            let sections = items.map { htmlSection($0, folders: folders) }.joined()
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

    private static func textSection(_ item: LibraryItem, folders: [LibraryFolder], markdown: Bool) -> String {
        var blocks: [String] = []
        blocks.append((markdown ? "# " : "") + item.title)
        blocks.append("Saved: " + stamp(item.createdAt))
        blocks.append("Folder: " + folderName(item, folders: folders))
        blocks.append("Category: " + (item.category ?? ""))
        blocks.append("Tags: " + (item.tags ?? []).joined(separator: ", "))
        blocks.append("Original: " + item.original)
        if let article = item.articleText { blocks.append(article) }
        for note in item.annotations {
            blocks.append((markdown ? "> " : "Highlight: ") + note.quote)
            blocks.append(note.comment)
            blocks.append("Created: " + stamp(note.createdAt))
            blocks.append("Edited: " + stamp(note.modifiedAt))
        }
        return blocks.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private static func htmlSection(_ item: LibraryItem, folders: [LibraryFolder]) -> String {
        let labels = [folderName(item, folders: folders), item.category ?? "", (item.tags ?? []).joined(separator: ", ")]
        var parts = ["<article><h1>", html(item.title), "</h1><p>", html(labels.joined(separator: " · ")),
                     "</p><small>Saved ", stamp(item.createdAt), "</small><h2>Original</h2><pre>",
                     html(item.original), "</pre><h2>Reading text</h2><pre>", html(item.readingText), "</pre>"]
        for note in item.annotations {
            parts.append(contentsOf: ["<blockquote>", html(note.quote), "</blockquote><p>", html(note.comment),
                "</p><small>Created ", stamp(note.createdAt), " · Edited ", stamp(note.modifiedAt), "</small>"])
        }
        parts.append("</article>")
        return parts.joined()
    }

    private static func folderName(_ item: LibraryItem, folders: [LibraryFolder]) -> String {
        folders.first { $0.id == item.folderID }?.name ?? ""
    }

    private static func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

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

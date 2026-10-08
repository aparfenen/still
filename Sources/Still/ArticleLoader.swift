import AppKit
import Foundation
import StillCore

struct ArticleSnapshot {
    var title: String
    var text: String
}

/// A deliberately conservative first reader. It never executes remote JavaScript.
@MainActor
enum ArticleLoader {
    static func load(_ url: URL) async throws -> ArticleSnapshot {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              ["text/html", "application/xhtml+xml"].contains(response.mimeType?.lowercased() ?? ""),
              ["https", "http"].contains(response.url?.scheme?.lowercased() ?? "") else {
            throw StoreError(message: "This page couldn't be prepared. Your original link is still available.")
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 2_000_000 else {
                throw StoreError(message: "This page is too large for the first-version reader. Open the original instead.")
            }
            data.append(byte)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw StoreError(message: "This page uses an unsupported encoding. Open the original instead.")
        }
        let titleHTML = firstCapture("<title\\b[^>]*>([\\s\\S]*?)</title>", in: html) ?? ""
        var body = firstCapture("<article\\b[^>]*>([\\s\\S]*?)</article>", in: html)
            ?? firstCapture("<main\\b[^>]*>([\\s\\S]*?)</main>", in: html)
            ?? firstCapture("<body\\b[^>]*>([\\s\\S]*?)</body>", in: html) ?? html
        // Remove active content, resource tags and page furniture before native HTML decoding.
        for tag in ["script", "style", "nav", "header", "footer", "aside", "form", "iframe", "object", "svg", "video", "audio"] {
            body = body.replacingOccurrences(of: "<" + tag + "\\b[^>]*>[\\s\\S]*?</" + tag + ">",
                                             with: "", options: [.regularExpression, .caseInsensitive])
        }
        body = body.replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
        let title = plain(titleHTML).trimmingCharacters(in: .whitespacesAndNewlines)
        let text = plain(body).components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
        guard text.count >= 80 else {
            throw StoreError(message: "There isn't enough readable text here. This site may require sign-in or JavaScript. Open the original instead.")
        }
        return ArticleSnapshot(title: title, text: text)
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func plain(_ text: String) -> String {
        // Encode angle brackets first: this is text, never a document with external resources.
        let escaped = text.replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
        guard let data = ("<html><body>" + escaped + "</body></html>").data(using: .utf8),
              let decoded = try? NSAttributedString(data: data,
                  options: [.documentType: NSAttributedString.DocumentType.html],
                  documentAttributes: nil) else { return text }
        return decoded.string
    }
}

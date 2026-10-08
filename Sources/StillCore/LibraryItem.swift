import Foundation

public enum ReadingStatus: String, Codable, CaseIterable, Sendable {
    case unread, reading, finished
}

public struct Annotation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var quote: String
    /// UTF-16 offsets match NSTextView. The quote verifies the anchor before rendering.
    public var location: Int
    public var length: Int
    public var comment: String
    public var createdAt: Date
    public var modifiedAt: Date

    public init(quote: String, range: NSRange, comment: String = "", now: Date = Date()) {
        id = UUID()
        self.quote = quote
        location = range.location
        length = range.length
        self.comment = comment
        createdAt = now
        modifiedAt = now
    }

    public func resolvedRange(in text: String) -> NSRange? {
        let source = text as NSString
        if location >= 0, length > 0, location <= source.length,
           length <= source.length - location {
            let range = NSRange(location: location, length: length)
            if source.substring(with: range) == quote { return range }
        }
        // Only recover a unique quotation; ambiguous matches must not move a highlight.
        let first = source.range(of: quote)
        guard !quote.isEmpty, first.location != NSNotFound else { return nil }
        let nextStart = first.location + first.length
        let second = source.range(of: quote, range: NSRange(
            location: nextStart, length: source.length - nextStart))
        return second.location == NSNotFound ? first : nil
    }
}

public struct LibraryItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var original: String
    public var title: String
    public var sourceApp: String?
    public var sourceBundleID: String?
    public var createdAt: Date
    public var lastCopiedAt: Date
    public var modifiedAt: Date
    public var captureCount: Int
    public var status: ReadingStatus
    public var isKept: Bool
    public var isManual: Bool
    public var articleText: String?
    public var snapshotAt: Date?
    public var readingOffset: Double
    public var annotations: [Annotation]

    public init(text: String, title: String = "", sourceApp: String? = nil,
                sourceBundleID: String? = nil, manual: Bool = true, now: Date = Date()) {
        id = UUID()
        original = text
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.suggestedTitle(for: text) : title
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        createdAt = now
        lastCopiedAt = now
        modifiedAt = now
        captureCount = 1
        status = .unread
        isKept = false
        isManual = manual
        articleText = nil
        snapshotAt = nil
        readingOffset = 0
        annotations = []
    }

    public var url: URL? {
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, !trimmed.contains(where: { $0.isWhitespace }) else { return nil }
        return url
    }

    public var readingText: String { articleText ?? original }
    public var isPermanent: Bool { isKept || isManual || !annotations.isEmpty }

    public func expiresAt(retentionDays: Int) -> Date? {
        guard !isPermanent else { return nil }
        return lastCopiedAt.addingTimeInterval(Double(max(1, retentionDays)) * 86_400)
    }

    public static func suggestedTitle(for text: String) -> String {
        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host {
            return host
        }
        return String(text.split(separator: "\n").first.map(String.init)?.prefix(72) ?? text.prefix(72))
    }
}

public struct LibraryArchive: Codable, Sendable {
    public var version: Int
    public var exportedAt: Date
    public var items: [LibraryItem]

    public init(items: [LibraryItem]) {
        version = 1
        exportedAt = Date()
        self.items = items
    }
}

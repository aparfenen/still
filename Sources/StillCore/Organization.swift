import Foundation

public struct LibraryFolder: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum Organization {
    public static func normalizedTags(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(separator: ",").compactMap { raw in
            let tag = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
            guard !tag.isEmpty, seen.insert(tag.lowercased()).inserted else { return nil }
            return tag
        }
    }
}

import Foundation
import CSQLite

public struct StoreError: LocalizedError {
    public let message: String
    public init(message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// Use on one queue only. The Mac app confines this store to its main actor.
public final class LibraryStore {
    private var db: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            let error = failure()
            if let db { sqlite3_close(db) }
            db = nil
            throw error
        }
        do {
            sqlite3_busy_timeout(db, 3_000)
            try execute("PRAGMA journal_mode=WAL;")
            try execute("PRAGMA synchronous=FULL;")
            let version = try scalarInt("PRAGMA user_version;")
            guard version <= 1 else {
                throw StoreError(message: "This library was created by a newer version of Still.")
            }
            if version == 0 {
                try transaction {
                    try execute("""
                    CREATE TABLE IF NOT EXISTS items (
                        id TEXT PRIMARY KEY, original TEXT NOT NULL UNIQUE,
                        payload TEXT NOT NULL, created REAL NOT NULL
                    );
                    CREATE INDEX IF NOT EXISTS items_created ON items(created DESC);
                    CREATE VIRTUAL TABLE IF NOT EXISTS item_search
                        USING fts5(id UNINDEXED, title, body, comments);
                    PRAGMA user_version=1;
                    """)
                }
            }
        } catch {
            if let db { sqlite3_close(db) }
            db = nil
            throw error
        }
    }

    deinit { if let db { sqlite3_close(db) } }

    public func all(query: String = "") throws -> [LibraryItem] {
        let words = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.isEmpty && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        let sql: String
        if words.isEmpty {
            sql = "SELECT payload FROM items ORDER BY created DESC;"
        } else {
            sql = """
            SELECT items.payload FROM items
            JOIN item_search ON item_search.id=items.id
            WHERE item_search MATCH ? ORDER BY items.created DESC;
            """
        }
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        if !words.isEmpty {
            let expression = words.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"*" }
                .joined(separator: " AND ")
            try bind(expression, to: statement, at: 1)
        }
        var result: [LibraryItem] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else { throw failure() }
            let payload = String(cString: text)
            result.append(try JSONDecoder().decode(LibraryItem.self, from: Data(payload.utf8)))
        }
        return result
    }

    @discardableResult
    public func capture(text: String, title: String = "", sourceApp: String? = nil,
                        sourceBundleID: String? = nil, manual: Bool,
                        now: Date = Date()) throws -> LibraryItem {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreError(message: "Paste a link or some text first.")
        }
        guard text.utf8.count <= 1_000_000 else {
            throw StoreError(message: "This item is too large. Save up to 1 MB of text at a time.")
        }
        let statement = try prepare("SELECT payload FROM items WHERE original=?;")
        defer { sqlite3_finalize(statement) }
        try bind(text, to: statement, at: 1)
        let step = sqlite3_step(statement)
        var item: LibraryItem
        if step == SQLITE_ROW, let payload = sqlite3_column_text(statement, 0) {
            item = try JSONDecoder().decode(LibraryItem.self, from: Data(String(cString: payload).utf8))
            item.captureCount += 1
            item.lastCopiedAt = now
            item.modifiedAt = now
            item.isManual = item.isManual || manual
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { item.title = title }
        } else if step == SQLITE_DONE {
            item = LibraryItem(text: text, title: title, sourceApp: sourceApp,
                               sourceBundleID: sourceBundleID, manual: manual, now: now)
        } else { throw failure() }
        // Release read cursor before starting a write transaction.
        sqlite3_reset(statement)
        try save(item)
        return item
    }

    public func save(_ item: LibraryItem) throws {
        try transaction { try write(item) }
    }

    public func delete(id: UUID) throws {
        try transaction {
            try deleteRow(id: id)
        }
    }

    public func prune(retentionDays: Int, now: Date = Date()) throws {
        let expired = try all().filter { ($0.expiresAt(retentionDays: retentionDays) ?? .distantFuture) <= now }
        guard !expired.isEmpty else { return }
        try transaction { for item in expired { try deleteRow(id: item.id) } }
    }

    public func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(LibraryArchive(items: all()))
    }

    /// Merge an archive atomically. On conflict preserve existing items and annotations.
    public func importData(_ data: Data) throws {
        guard data.count <= 100_000_000 else { throw StoreError(message: "The archive is too large.") }
        let archive = try JSONDecoder().decode(LibraryArchive.self, from: data)
        guard archive.version == 1 else { throw StoreError(message: "Unsupported archive version.") }
        let existing = try all()
        var ids = Set(existing.map(\.id))
        var originals = Set(existing.map(\.original))
        try transaction {
            for item in archive.items {
                guard !item.original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      item.original.utf8.count <= 1_000_000,
                      item.readingText.utf8.count <= 5_000_000,
                      item.captureCount > 0,
                      item.readingOffset.isFinite, item.readingOffset >= 0,
                      item.annotations.allSatisfy({ $0.location >= 0 && $0.length > 0 && !$0.quote.isEmpty })
                else { throw StoreError(message: "The archive contains an invalid item.") }
                guard !ids.contains(item.id), !originals.contains(item.original) else { continue }
                try write(item)
                ids.insert(item.id)
                originals.insert(item.original)
            }
        }
    }

    private func write(_ item: LibraryItem) throws {
        let data = try JSONEncoder().encode(item)
        let statement = try prepare("""
        INSERT INTO items(id,original,payload,created) VALUES(?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET original=excluded.original,payload=excluded.payload,created=excluded.created;
        """)
        defer { sqlite3_finalize(statement) }
        try bind(item.id.uuidString, to: statement, at: 1)
        try bind(item.original, to: statement, at: 2)
        try bind(String(decoding: data, as: UTF8.self), to: statement, at: 3)
        guard sqlite3_bind_double(statement, 4, item.createdAt.timeIntervalSince1970) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
        try run("DELETE FROM item_search WHERE id=?;", values: [item.id.uuidString])
        try run("INSERT INTO item_search(id,title,body,comments) VALUES(?,?,?,?);",
                values: [item.id.uuidString, item.title, item.original + "\n" + (item.articleText ?? ""),
                         item.annotations.map { $0.quote + "\n" + $0.comment }.joined(separator: "\n")])
    }

    private func deleteRow(id: UUID) throws {
        try run("DELETE FROM items WHERE id=?;", values: [id.uuidString])
        try run("DELETE FROM item_search WHERE id=?;", values: [id.uuidString])
    }

    private func run(_ sql: String, values: [String]) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() { try bind(value, to: statement, at: Int32(index + 1)) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    private func bind(_ value: String, to statement: OpaquePointer, at index: Int32) throws {
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else { throw failure() }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        return statement
    }

    private func scalarInt(_ sql: String) throws -> Int32 {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw failure() }
        return sqlite3_column_int(statement, 0)
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }

    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE;")
        do {
            try body()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func failure() -> StoreError {
        // Do not expose SQLite messages which may contain user content in UI or logs.
        StoreError(message: "Still couldn't access the library (SQLite code \(sqlite3_errcode(db))). Your saved data has not been reset.")
    }
}

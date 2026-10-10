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
            guard version <= 3 else {
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
            if version < 2 {
                try transaction {
                    try execute("CREATE TABLE IF NOT EXISTS folders (id TEXT PRIMARY KEY, name TEXT NOT NULL, name_key TEXT NOT NULL UNIQUE); PRAGMA user_version=2;")
                }
            }
            if version < 3 {
                try transaction {
                    // Idempotent when migrating an older test fixture with this column already present.
                    let columns = try columnNames()
                    if !columns.contains("deleted") { try execute("ALTER TABLE items ADD COLUMN deleted REAL;") }
                    try execute("CREATE INDEX IF NOT EXISTS items_deleted ON items(deleted); PRAGMA user_version=3;")
                }
            }
        } catch {
            if let db { sqlite3_close(db) }
            db = nil
            throw error
        }
    }

    deinit { if let db { sqlite3_close(db) } }

    public func all(query: String = "", includeDeleted: Bool = false) throws -> [LibraryItem] {
        let words = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.isEmpty && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        let sql: String
        if words.isEmpty {
            sql = "SELECT payload FROM items" + (includeDeleted ? "" : " WHERE deleted IS NULL") + " ORDER BY created DESC;"
        } else {
            sql = """
            SELECT items.payload FROM items
            JOIN item_search ON item_search.id=items.id
            WHERE item_search MATCH ? \(includeDeleted ? "" : "AND items.deleted IS NULL") ORDER BY items.created DESC;
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
            if item.deletedAt != nil && !manual { sqlite3_reset(statement); return item }
            item.deletedAt = nil
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
        if let folderID = item.folderID, !(try folders()).contains(where: { $0.id == folderID }) {
            throw StoreError(message: "That folder no longer exists. Choose another folder.")
        }
        guard (item.category ?? "").count <= 80, (item.tags ?? []).count <= 100,
              (item.tags ?? []).allSatisfy({ !$0.isEmpty && $0.count <= 60 }) else {
            throw StoreError(message: "Use up to 100 tags of 60 characters and a category of 80 characters.")
        }
        try transaction { try write(item) }
    }

    public func delete(id: UUID) throws {
        guard var item = try all(includeDeleted: true).first(where: { $0.id == id }) else { return }
        item.deletedAt = Date(); item.modifiedAt = Date()
        try save(item)
    }

    public func restore(id: UUID) throws {
        guard var item = try all(includeDeleted: true).first(where: { $0.id == id }) else { return }
        item.deletedAt = nil; item.isKept = true; item.modifiedAt = Date()
        try save(item)
    }

    public func prune(retentionDays: Int, now: Date = Date()) throws {
        let expired = try all(includeDeleted: true).filter {
            if let deleted = $0.deletedAt { return deleted.addingTimeInterval(30 * 86400) <= now }
            return ($0.expiresAt(retentionDays: retentionDays) ?? .distantFuture) <= now
        }
        guard !expired.isEmpty else { return }
        try transaction { for item in expired { try deleteRow(id: item.id) } }
    }

    public func folders() throws -> [LibraryFolder] {
        let statement = try prepare("SELECT id,name FROM folders ORDER BY name_key;")
        defer { sqlite3_finalize(statement) }
        var result: [LibraryFolder] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW,
                  let rawID = sqlite3_column_text(statement, 0),
                  let name = sqlite3_column_text(statement, 1),
                  let id = UUID(uuidString: String(cString: rawID)) else { throw failure() }
            result.append(LibraryFolder(id: id, name: String(cString: name)))
        }
        return result
    }

    public func saveFolder(_ folder: LibraryFolder) throws {
        let name = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else {
            throw StoreError(message: "Use a folder name between 1 and 80 characters.")
        }
        let key = name.lowercased()
        guard !(try folders()).contains(where: { $0.id != folder.id && $0.name.lowercased() == key }) else {
            throw StoreError(message: "A folder with that name already exists.")
        }
        try run("""
        INSERT INTO folders(id,name,name_key) VALUES(?,?,?)
        ON CONFLICT(id) DO UPDATE SET name=excluded.name,name_key=excluded.name_key;
        """, values: [folder.id.uuidString, name, key])
    }

    public func deleteFolder(id: UUID) throws {
        let assigned = try all(includeDeleted: true).filter { $0.folderID == id }
        try transaction {
            for var item in assigned {
                item.folderID = nil
                // Deleting the folder must not turn its saved items back into expiring history.
                item.isKept = true
                item.modifiedAt = Date()
                try write(item)
            }
            try run("DELETE FROM folders WHERE id=?;", values: [id.uuidString])
        }
    }

    public func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(LibraryArchive(items: all(includeDeleted: true), folders: folders()))
    }

    /// Merge atomically; preserve existing items and map folders with matching names.
    public func importData(_ data: Data) throws {
        guard data.count <= 100_000_000 else { throw StoreError(message: "The archive is too large.") }
        let archive = try JSONDecoder().decode(LibraryArchive.self, from: data)
        guard [1, 2, 3].contains(archive.version) else { throw StoreError(message: "Unsupported archive version.") }
        guard Set(archive.items.map(\.id)).count == archive.items.count,
              Set(archive.items.map(\.original)).count == archive.items.count else {
            throw StoreError(message: "The archive contains duplicate records. Nothing was imported.")
        }
        let existing = try all(includeDeleted: true)
        var ids = Set(existing.map(\.id))
        var originals = Set(existing.map(\.original))
        var knownFolders = try folders()
        var folderMap: [UUID: UUID] = [:]
        try transaction {
            for folder in archive.folders ?? [] {
                if let sameID = knownFolders.first(where: { $0.id == folder.id }) {
                    folderMap[folder.id] = sameID.id
                } else if let sameName = knownFolders.first(where: { $0.name.lowercased() == folder.name.lowercased() }) {
                    folderMap[folder.id] = sameName.id
                } else {
                    try saveFolder(folder)
                    knownFolders.append(folder)
                    folderMap[folder.id] = folder.id
                }
            }
            for var item in archive.items {
                guard !item.original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      item.original.utf8.count <= 1_000_000,
                      item.readingText.utf8.count <= 5_000_000,
                      item.captureCount > 0,
                      item.readingOffset.isFinite, item.readingOffset >= 0,
                      (item.tags ?? []).count <= 100,
                      (item.category ?? "").count <= 80,
                      Set(item.annotations.map(\.id)).count == item.annotations.count,
                      (item.tags ?? []).allSatisfy({ !$0.isEmpty && $0.count <= 60 })
                else { throw StoreError(message: "The archive contains an invalid item.") }
                guard !ids.contains(item.id), !originals.contains(item.original) else { continue }
                if let folderID = item.folderID {
                    guard let mapped = folderMap[folderID] ?? knownFolders.first(where: { $0.id == folderID })?.id else {
                        throw StoreError(message: "An imported item refers to a missing folder.")
                    }
                    item.folderID = mapped
                }
                try write(item)
                ids.insert(item.id)
                originals.insert(item.original)
            }
        }
    }

    private func write(_ item: LibraryItem) throws {
        let data = try JSONEncoder().encode(item)
        let statement = try prepare("""
        INSERT INTO items(id,original,payload,created,deleted) VALUES(?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET original=excluded.original,payload=excluded.payload,created=excluded.created,deleted=excluded.deleted;
        """)
        defer { sqlite3_finalize(statement) }
        try bind(item.id.uuidString, to: statement, at: 1)
        try bind(item.original, to: statement, at: 2)
        try bind(String(decoding: data, as: UTF8.self), to: statement, at: 3)
        if let deleted = item.deletedAt { sqlite3_bind_double(statement, 5, deleted.timeIntervalSince1970) }
        else { sqlite3_bind_null(statement, 5) }
        guard sqlite3_bind_double(statement, 4, item.createdAt.timeIntervalSince1970) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
        try run("DELETE FROM item_search WHERE id=?;", values: [item.id.uuidString])
        let notes = item.annotations.map { [$0.quote, $0.comment].joined(separator: "\n") }.joined(separator: "\n")
        let labels = (item.tags ?? []).joined(separator: " ")
        let searchComments = [notes, labels, item.category ?? ""].joined(separator: "\n")
        let searchBody = [item.original, item.articleText ?? ""].joined(separator: "\n")
        try run("INSERT INTO item_search(id,title,body,comments) VALUES(?,?,?,?);",
                values: [item.id.uuidString, item.title, searchBody, searchComments])
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

    private func columnNames() throws -> Set<String> {
        let statement = try prepare("PRAGMA table_info(items)"); defer { sqlite3_finalize(statement) }
        var names = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW { if let name = sqlite3_column_text(statement, 1) { names.insert(String(cString: name)) } }
        return names
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

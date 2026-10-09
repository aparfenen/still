import XCTest
import CSQLite
@testable import StillCore

final class LibraryStoreTests: XCTestCase {
    private var directory: URL!
    private var store: LibraryStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = try LibraryStore(url: directory.appendingPathComponent("library.sqlite"))
    }

    override func tearDownWithError() throws {
        store = nil
        try FileManager.default.removeItem(at: directory)
    }

    func testRepeatedCapturePreservesIdentityAndAnnotations() throws {
        var original = try store.capture(text: "Attention needs a place to rest.", manual: false)
        original.annotations = [Annotation(quote: "Attention", range: NSRange(location: 0, length: 9),
                                           comment: "For onboarding")]
        original.status = .reading
        try store.save(original)
        let repeated = try store.capture(text: original.original, manual: true)
        XCTAssertEqual(repeated.id, original.id)
        XCTAssertEqual(repeated.captureCount, 2)
        XCTAssertTrue(repeated.isManual)
        XCTAssertEqual(repeated.annotations, original.annotations)
        XCTAssertEqual(repeated.status, .reading)
        XCTAssertEqual(try store.all().count, 1)
    }

    func testFullTextSearchIndexesCommentsAndDeletesWithItem() throws {
        var item = try store.capture(text: "A quiet morning", manual: true)
        item.annotations = [Annotation(quote: "quiet", range: NSRange(location: 2, length: 5),
                                      comment: "Research for onboarding")]
        try store.save(item)
        XCTAssertEqual(try store.all(query: "onboard").map(\.id), [item.id])
        XCTAssertEqual(try store.all(query: "quiet morning").map(\.id), [item.id])
        // User syntax is quoted, never executed as FTS operators or SQL.
        XCTAssertNoThrow(try store.all(query: "\" OR *"))
        try store.delete(id: item.id)
        XCTAssertTrue(try store.all(query: "onboard").isEmpty)
    }

    func testRetentionOnlyDeletesExpiredTemporaryItems() throws {
        let old = Date(timeIntervalSince1970: 1_000)
        _ = try store.capture(text: "Temporary", manual: false, now: old)
        let manual = try store.capture(text: "Manual", manual: true, now: old)
        var kept = try store.capture(text: "Kept", manual: false, now: old)
        kept.isKept = true
        try store.save(kept)
        var annotated = try store.capture(text: "Annotated", manual: false, now: old)
        annotated.annotations = [Annotation(quote: "Annotated", range: NSRange(location: 0, length: 9))]
        try store.save(annotated)
        try store.prune(retentionDays: 7, now: old.addingTimeInterval(8 * 86400))
        XCTAssertEqual(Set(try store.all().map(\.id)), Set([manual.id, kept.id, annotated.id]))
    }

    func testReopenAndArchiveRoundTripPreserveUnicodeAndTimestamps() throws {
        var item = try store.capture(text: "🖤 A café in Paris", sourceApp: "Notes", manual: true)
        item.articleText = "🖤 A café in Paris\n\nA quiet place."
        item.snapshotAt = Date(timeIntervalSince1970: 12_345)
        item.readingOffset = 34
        item.annotations = [Annotation(quote: "café", range: NSRange(location: 5, length: 4),
                                      comment: "Return here", now: Date(timeIntervalSince1970: 120))]
        try store.save(item)
        let exported = try store.exportData()
        store = nil
        store = try LibraryStore(url: directory.appendingPathComponent("library.sqlite"))
        XCTAssertEqual(try store.all().first, item)
        let restored = try LibraryStore(url: directory.appendingPathComponent("restore/library.sqlite"))
        try restored.importData(exported)
        XCTAssertEqual(try restored.all().first, item)
        try restored.importData(exported)
        XCTAssertEqual(try restored.all().count, 1)
    }

    func testInvalidArchiveRollsBackEveryImportedItem() throws {
        let valid = LibraryItem(text: "Valid", manual: true)
        var invalid = LibraryItem(text: "Invalid", manual: true)
        invalid.captureCount = 0
        let data = try JSONEncoder().encode(LibraryArchive(items: [valid, invalid]))
        XCTAssertThrowsError(try store.importData(data))
        XCTAssertTrue(try store.all().isEmpty)
    }

    func testUnknownArchiveVersionIsRejected() throws {
        var archive = LibraryArchive(items: [LibraryItem(text: "Future", manual: true)])
        archive.version = 3
        XCTAssertThrowsError(try store.importData(JSONEncoder().encode(archive)))
        XCTAssertTrue(try store.all().isEmpty)
    }

    func testHighlightAnchorRecoversOnlyUniqueQuotation() {
        let note = Annotation(quote: "calm", range: NSRange(location: 0, length: 4))
        XCTAssertEqual(note.resolvedRange(in: "A calm place"), NSRange(location: 2, length: 4))
        XCTAssertNil(note.resolvedRange(in: "A calm and calm place"))
        XCTAssertNil(note.resolvedRange(in: "No matching phrase"))
        let emoji = Annotation(quote: "🖤", range: NSRange(location: 0, length: 2))
        XCTAssertEqual(emoji.resolvedRange(in: "🖤 Still"), NSRange(location: 0, length: 2))
    }

    func testInvalidURLAndWhitespaceCapture() throws {
        XCTAssertNil(LibraryItem(text: "file:///etc/passwd").url)
        XCTAssertNil(LibraryItem(text: "https://example.com some text").url)
        XCTAssertEqual(LibraryItem(text: "https://example.com").url?.host, "example.com")
        XCTAssertThrowsError(try store.capture(text: "  \n ", manual: true))
    }
    func testLegacyArchiveWithoutOrganizationStillImports() throws {
        let item = LibraryItem(text: "Old saved content", manual: true)
        let encoder = JSONEncoder()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(item)) as? [String: Any])
        object.removeValue(forKey: "tags")
        object.removeValue(forKey: "folderID")
        object.removeValue(forKey: "category")
        let archive: [String: Any] = ["version": 1, "exportedAt": 0, "items": [object]]
        try store.importData(JSONSerialization.data(withJSONObject: archive))
        XCTAssertEqual(try store.all().first?.original, item.original)
        XCTAssertNil(try store.all().first?.folderID)
    }

    func testSchemaOneMigrationPreservesItemsAndAddsFolders() throws {
        let item = try store.capture(text: "Before migration", manual: true)
        store = nil
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(directory.appendingPathComponent("library.sqlite").path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "DROP TABLE folders; PRAGMA user_version=1;", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        store = try LibraryStore(url: directory.appendingPathComponent("library.sqlite"))
        XCTAssertEqual(try store.all().first?.id, item.id)
        XCTAssertTrue(try store.folders().isEmpty)
        try store.saveFolder(LibraryFolder(name: "Research"))
        XCTAssertEqual(try store.folders().count, 1)
    }

    func testOrganizationSearchAndFolderDeletionPreserveContent() throws {
        let folder = LibraryFolder(name: "Design")
        try store.saveFolder(folder)
        var item = try store.capture(text: "A saved passage", manual: false,
                                     now: Date(timeIntervalSince1970: 0))
        item.folderID = folder.id
        item.tags = ["lavender", "inspiration"]
        item.category = "Art"
        try store.save(item)
        XCTAssertEqual(try store.all(query: "lavender").first?.id, item.id)
        XCTAssertEqual(try store.all(query: "Art").first?.id, item.id)
        try store.prune(retentionDays: 1)
        XCTAssertEqual(try store.all().count, 1)
        try store.deleteFolder(id: folder.id)
        XCTAssertNil(try store.all().first?.folderID)
        XCTAssertTrue(try XCTUnwrap(store.all().first).isKept)
        XCTAssertTrue(try store.folders().isEmpty)
    }

    func testFolderArchiveMergesMatchingNamesAndPreservesTags() throws {
        let local = LibraryFolder(name: "Research")
        try store.saveFolder(local)
        let imported = LibraryFolder(name: "Research")
        var item = LibraryItem(text: "Imported research")
        item.folderID = imported.id
        item.tags = ["Ideas"]
        item.category = "Writing"
        let archive = LibraryArchive(items: [item], folders: [imported])
        try store.importData(JSONEncoder().encode(archive))
        XCTAssertEqual(try store.folders().count, 1)
        XCTAssertEqual(try store.all().first?.folderID, local.id)
        XCTAssertEqual(try store.all().first?.tags, ["Ideas"])
        let copy = try LibraryStore(url: directory.appendingPathComponent("copy/library.sqlite"))
        try copy.importData(store.exportData())
        XCTAssertEqual(try copy.folders(), try store.folders())
        XCTAssertEqual(try copy.all(), try store.all())
    }

    func testFolderNamesAndTagNormalization() throws {
        try store.saveFolder(LibraryFolder(name: "Work"))
        XCTAssertThrowsError(try store.saveFolder(LibraryFolder(name: "work")))
        XCTAssertThrowsError(try store.saveFolder(LibraryFolder(name: " ")))
        XCTAssertEqual(Organization.normalizedTags(" Art, art, Research, , Ideas "), ["Art", "Research", "Ideas"])
    }

    func testReadableExportsEscapeHTMLAndSpreadsheetFormulas() throws {
        var item = LibraryItem(text: "<script>alert(1)</script>", title: "=1+1")
        item.tags = ["art"]
        let csv = String(decoding: try LibraryExport.data(items: [item], folders: [], format: .csv), as: UTF8.self)
        XCTAssertTrue(csv.contains("'=1+1"))
        let html = String(decoding: try LibraryExport.data(items: [item], folders: [], format: .html), as: UTF8.self)
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        for format in [LibraryExportFormat.markdown, .text] {
            let text = String(decoding: try LibraryExport.data(items: [item], folders: [], format: format), as: UTF8.self)
            XCTAssertTrue(text.contains(item.original))
            XCTAssertTrue(text.contains("art"))
        }
    }

}

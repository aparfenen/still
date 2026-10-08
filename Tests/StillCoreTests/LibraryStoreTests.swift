import XCTest
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
        archive.version = 2
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
}

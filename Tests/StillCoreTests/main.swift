import Foundation
import StillCore

// Dependency-free assertions so the suite runs with Apple Command Line Tools.
var failures = 0
func fail(_ message: String, file: StaticString, line: UInt) { failures += 1; print("FAIL \(file):\(line): \(message)") }
func XCTAssertEqual<T: Equatable>(_ lhs: @autoclosure () throws -> T, _ rhs: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { if try lhs() != rhs() { fail("values differ", file: file, line: line) } } catch { fail("unexpected error", file: file, line: line) }
}
func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    do { if try !value() { fail("expected true", file: file, line: line) } } catch { fail("unexpected error", file: file, line: line) }
}
func XCTAssertFalse(_ value: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    do { if try value() { fail("expected false", file: file, line: line) } } catch { fail("unexpected error", file: file, line: line) }
}
func XCTAssertNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { if value != nil { fail("expected nil", file: file, line: line) } }
func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { if value == nil { fail("expected non-nil", file: file, line: line) } }
func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try expression() } catch { fail("unexpected error: \(error)", file: file, line: line) }
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try expression(); fail("expected an error", file: file, line: line) } catch {}
}

class XCTestCase {
    func setUpWithError() throws {}
    func tearDownWithError() throws {}
}
struct UnwrapError: Error {}
func XCTUnwrap<T>(_ value: @autoclosure () throws -> T?) throws -> T {
    guard let unwrapped = try value() else { throw UnwrapError() }; return unwrapped
}
let tests = LibraryStoreTests()
let cases: [(String, () throws -> Void)] = [
    ("testRepeatedCapturePreservesIdentityAndAnnotations", tests.testRepeatedCapturePreservesIdentityAndAnnotations),
    ("testFullTextSearchIndexesCommentsAndDeletesWithItem", tests.testFullTextSearchIndexesCommentsAndDeletesWithItem),
    ("testRetentionOnlyDeletesExpiredTemporaryItems", tests.testRetentionOnlyDeletesExpiredTemporaryItems),
    ("testReopenAndArchiveRoundTripPreserveUnicodeAndTimestamps", tests.testReopenAndArchiveRoundTripPreserveUnicodeAndTimestamps),
    ("testInvalidArchiveRollsBackEveryImportedItem", tests.testInvalidArchiveRollsBackEveryImportedItem),
    ("testUnknownArchiveVersionIsRejected", tests.testUnknownArchiveVersionIsRejected),
    ("testHighlightAnchorRecoversOnlyUniqueQuotation", tests.testHighlightAnchorRecoversOnlyUniqueQuotation),
    ("testInvalidURLAndWhitespaceCapture", tests.testInvalidURLAndWhitespaceCapture),
    ("testLegacyArchiveWithoutOrganizationStillImports", tests.testLegacyArchiveWithoutOrganizationStillImports),
    ("testSchemaOneMigrationPreservesItemsAndAddsFolders", tests.testSchemaOneMigrationPreservesItemsAndAddsFolders),
    ("testOrganizationSearchAndFolderDeletionPreserveContent", tests.testOrganizationSearchAndFolderDeletionPreserveContent),
    ("testFolderArchiveMergesMatchingNamesAndPreservesTags", tests.testFolderArchiveMergesMatchingNamesAndPreservesTags),
    ("testFolderNamesAndTagNormalization", tests.testFolderNamesAndTagNormalization),
    ("testReadableExportsEscapeHTMLAndSpreadsheetFormulas", tests.testReadableExportsEscapeHTMLAndSpreadsheetFormulas),
    ("testRecentlyDeletedAndUndoPreserveAnnotationsAndOrganization", tests.testRecentlyDeletedAndUndoPreserveAnnotationsAndOrganization),
    ("testDeletedBackupRoundTripAndThirtyDayPurge", tests.testDeletedBackupRoundTripAndThirtyDayPurge),
    ("testAutomaticRecaptureDoesNotRestoreTrash", tests.testAutomaticRecaptureDoesNotRestoreTrash)
]
for (name, test) in cases {
    let before = failures
    do {
        try tests.setUpWithError()
        defer { try? tests.tearDownWithError() }
        try test()
    } catch { failures += 1; print("FAIL \(name): \(error)") }
    if before == failures { print("PASS \(name)") }
}
print("\(cases.count) tests; \(failures) failures")
if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--verify-backup" {
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let expected = try JSONDecoder().decode(LibraryArchive.self, from: data)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.sqlite")
        var restored: LibraryStore? = try LibraryStore(url: url)
        try restored!.importData(data)
        restored = nil
        restored = try LibraryStore(url: url)
        XCTAssertEqual(Set(try restored!.all(includeDeleted: true).map(\.id)), Set(expected.items.map(\.id)))
        for item in expected.items {
            XCTAssertEqual(try restored!.all(includeDeleted: true).first { $0.id == item.id }, item)
        }
        restored = nil
        print("Native backup restored and reopened: \(expected.items.count) items; \(failures) total failures")
    } catch { failures += 1; print("FAIL native backup: \(error)") }
}
exit(failures == 0 ? 0 : 1)

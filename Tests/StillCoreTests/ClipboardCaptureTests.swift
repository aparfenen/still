import AppKit
import StillCore
#if !STILL_STANDALONE
import XCTest
#endif

extension LibraryStoreTests {
    func testClipboardPrivacyBoundaries() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        var reader = ClipboardCapture(changeCount: board.changeCount)
        func write(_ text: String) {
            board.clearContents()
            board.setString(text, forType: .string)
        }
        for marker in ClipboardCapture.sensitiveTypes {
            write("Synthetic protected passage")
            board.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
            XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "editor" }))
            XCTAssertEqual(reader.changeCount, board.changeCount)
        }
        for source: String? in ["excluded.editor", "still", nil] {
            write("Synthetic excluded passage")
            XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: " other.app\nexcluded.editor\t", ownBundleID: "still", frontmostBundleID: { source }))
            // Switching to an allowed app must not expose a rejected generation.
            XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "allowed.editor" }))
        }
        write("Ordinary passage")
        XCTAssertEqual(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "editor" }), "Ordinary passage")
    }

    func testClipboardPauseAndContentLimits() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        var reader = ClipboardCapture(changeCount: board.changeCount)
        board.clearContents()
        board.setString("Copied while paused", forType: .string)
        XCTAssertNil(reader.read(from: board, enabled: false, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "editor" }))
        reader.reset(to: board.changeCount)
        XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "editor" }))
        board.clearContents()
        board.setString("New Unicode copy 🌱", forType: .string)
        XCTAssertEqual(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "editor" }), "New Unicode copy 🌱")
        XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "editor" }))
        for text in [" \n\t", String(repeating: "é", count: 500_001)] {
            board.clearContents()
            board.setString(text, forType: .string)
            XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "editor" }))
        }
        board.clearContents()
        board.setData(Data([0, 1, 2]), forType: .png)
        XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: { "editor" }))
    }

    func testClipboardRejectsChangesDuringRead() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        var reader = ClipboardCapture(changeCount: board.changeCount)
        board.clearContents()
        board.setString("Synthetic race", forType: .string)
        var calls = 0
        XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: {
            calls += 1
            return calls == 1 ? "editor" : "other"
        }))
        board.clearContents()
        board.setString("Before change", forType: .string)
        calls = 0
        XCTAssertNil(reader.read(from: board, enabled: true, excludedApps: "", ownBundleID: "still", frontmostBundleID: {
            calls += 1
            if calls == 2 {
                board.clearContents()
                board.setString("After change", forType: .string)
                board.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
            }
            return "editor"
        }))
    }
}

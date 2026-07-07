/// SourceFindHighlightTests - Source-pane find highlighting (C5)
///
/// Proves that highlighting the source editor is non-destructive (the document text is
/// byte-for-byte unchanged) and that match counts / regex validity are reported correctly.

#if os(macOS)
import XCTest
import AppKit
@testable import ViewerUI

@MainActor
final class SourceFindHighlightTests: XCTestCase {

    /// Builds a laid-out LineNumberTextView with `content`.
    /// - Input: `content` (String). - Output: the text view inside a scroll view.
    private func makeTextView(_ content: String) -> LineNumberTextView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(containerSize: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = LineNumberTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), textContainer: container)
        textView.string = content
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        scrollView.documentView = textView
        textView.layoutManager?.ensureLayout(for: container)
        return textView
    }

    /// Function: `applyFindHighlights(query:options:currentIndex:active:)`.
    /// Input: a document, query "line" (case-insensitive). Output: count == occurrences,
    /// regexInvalid == false, and the document string is UNCHANGED (non-destructive).
    func testHighlightDoesNotMutateDocument() {
        let content = "Line one\nline two\nLINE three\nother"
        let textView = makeTextView(content)

        let result = textView.applyFindHighlights(
            query: "line",
            options: FindOptions(),
            currentIndex: 0,
            active: true
        )

        XCTAssertEqual(result.count, 3, "Case-insensitive 'line' matches three lines")
        XCTAssertFalse(result.regexInvalid)
        XCTAssertEqual(textView.string, content, "Highlighting must not modify the document text")
    }

    /// Function: `applyFindHighlights` then `clearFindHighlights`.
    /// Input: apply then clear. Output: document text still identical to the original.
    func testClearLeavesDocumentIntact() {
        let content = "alpha beta alpha"
        let textView = makeTextView(content)

        textView.applyFindHighlights(query: "alpha", options: FindOptions(), currentIndex: 0, active: true)
        textView.clearFindHighlights()

        XCTAssertEqual(textView.string, content)
    }

    /// Function: `applyFindHighlights` with `active = false`.
    /// Input: active false. Output: zero count, no highlight, text unchanged.
    func testInactiveProducesNoMatches() {
        let content = "match match"
        let textView = makeTextView(content)

        let result = textView.applyFindHighlights(query: "match", options: FindOptions(), currentIndex: 0, active: false)

        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(textView.string, content)
    }

    /// Negative self-test. Function: `applyFindHighlights` with an invalid regex.
    /// Input: query "[", regex on, active. Output: count 0, regexInvalid true, text unchanged.
    func testInvalidRegexReportsInvalidWithoutMutating() {
        let content = "some text"
        let textView = makeTextView(content)

        let result = textView.applyFindHighlights(
            query: "[",
            options: FindOptions(useRegex: true),
            currentIndex: 0,
            active: true
        )

        XCTAssertEqual(result.count, 0)
        XCTAssertTrue(result.regexInvalid)
        XCTAssertEqual(textView.string, content)
    }

    /// Function: `applyFindHighlights` case-sensitive vs default.
    /// Input: content with mixed case, query "Line" case-sensitive. Output: count 1.
    func testCaseSensitiveCount() {
        let textView = makeTextView("Line line LINE")
        let result = textView.applyFindHighlights(
            query: "Line",
            options: FindOptions(caseSensitive: true),
            currentIndex: 0,
            active: true
        )
        XCTAssertEqual(result.count, 1)
    }
}
#endif

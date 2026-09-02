import MarkdownCore
@testable import ViewerUI
import XCTest

final class ContentLineSynchronizerTests: XCTestCase {
    /// Function: `containingBlockSourceLine(for:in:)`.
    /// Input: source lines 1...8 and three ordered Markdown blocks.
    /// Output: the source line of the rendered block containing each positive line.
    func testFocusedLineMapsToContainingRenderedBlock() {
        let blocks = [
            MarkdownBlock(id: 0, kind: .paragraph, sourceLine: 1),
            MarkdownBlock(id: 1, kind: .heading(level: 1), sourceLine: 5),
            MarkdownBlock(id: 2, kind: .paragraph, sourceLine: 8)
        ]

        XCTAssertEqual(ContentLineSynchronizer.containingBlockSourceLine(for: 1, in: blocks), 1)
        XCTAssertEqual(ContentLineSynchronizer.containingBlockSourceLine(for: 4, in: blocks), 1)
        XCTAssertEqual(ContentLineSynchronizer.containingBlockSourceLine(for: 6, in: blocks), 5)
        XCTAssertEqual(ContentLineSynchronizer.containingBlockSourceLine(for: 8, in: blocks), 8)
        XCTAssertNil(ContentLineSynchronizer.containingBlockSourceLine(for: 0, in: blocks))
    }

    /// Function: `contains(focusedLine:blockSourceLine:nextBlockSourceLine:)`.
    /// Input: focused lines at, inside, before, and after a block range.
    /// Output: true only for lines in the block's inclusive source range.
    func testBlockHighlightCoversMultilineSourceRangeOnly() {
        XCTAssertTrue(ContentLineSynchronizer.contains(
            focusedLine: 3,
            blockSourceLine: 3,
            nextBlockSourceLine: 7
        ))
        XCTAssertTrue(ContentLineSynchronizer.contains(
            focusedLine: 6,
            blockSourceLine: 3,
            nextBlockSourceLine: 7
        ))
        XCTAssertFalse(ContentLineSynchronizer.contains(
            focusedLine: 7,
            blockSourceLine: 3,
            nextBlockSourceLine: 7
        ))
        XCTAssertFalse(ContentLineSynchronizer.contains(
            focusedLine: 2,
            blockSourceLine: 3,
            nextBlockSourceLine: 7
        ))
    }

    /// Function: `renderedAnchorLine(for:in:)`.
    /// Input: one list with three rows and one table with header/body rows.
    /// Output: exact row lines for list/table content and block-start fallback elsewhere.
    func testRenderedAnchorUsesExactStructuredRowLine() {
        let blocks = [
            MarkdownBlock(
                id: 0,
                kind: .unorderedList,
                sourceLine: 2,
                listItems: [[InlineRun(text: "one")], [InlineRun(text: "two")], [InlineRun(text: "three")]]
            ),
            MarkdownBlock(
                id: 1,
                kind: .table,
                sourceLine: 8,
                tableRows: [
                    [[InlineRun(text: "header")]],
                    [[InlineRun(text: "body")]]
                ]
            )
        ]

        XCTAssertEqual(ContentLineSynchronizer.renderedAnchorLine(for: 4, in: blocks), 4)
        XCTAssertEqual(ContentLineSynchronizer.renderedAnchorLine(for: 6, in: blocks), 2)
        XCTAssertEqual(ContentLineSynchronizer.renderedAnchorLine(for: 9, in: blocks), 8)
        XCTAssertEqual(ContentLineSynchronizer.renderedAnchorLine(for: 10, in: blocks), 10)
    }
}

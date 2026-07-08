// ContentFindHighlighterTests - Content-pane highlight mapping (C4)
//
// Proves that matches found in a rendered `AttributedString` are highlighted on the
// correct character ranges (the index mapping between the plain string and the
// AttributedString), that the current occurrence is emphasized distinctly, and that
// empty/no-match inputs are pass-through.

import SwiftUI
@testable import ViewerUI
import XCTest

final class ContentFindHighlighterTests: XCTestCase {
    /// Collects the background colors applied per run in the result, in order.
    private func backgroundRuns(_ attr: AttributedString) -> [Color] {
        attr.runs.compactMap { $0.backgroundColor }
    }

    /// Function: `highlight(_:query:options:currentOccurrence:)`.
    /// Input: "the fox and the fox"; query "fox"; no current. Output: 2 runs get the match color.
    func testHighlightsAllMatches() {
        let source = AttributedString("the fox and the fox")
        let result = ContentFindHighlighter.highlight(
            source,
            query: "fox",
            options: FindOptions(),
            currentOccurrence: nil
        )

        let colored = backgroundRuns(result)
        XCTAssertEqual(colored.count, 2, "Both 'fox' occurrences should be highlighted")
        XCTAssertTrue(colored.allSatisfy { $0 == ContentFindHighlighter.matchColor })
    }

    /// Function: `highlight` with a current occurrence.
    /// Input: two matches, currentOccurrence = 1. Output: one run is the current color, one the match color.
    func testCurrentOccurrenceEmphasized() {
        let source = AttributedString("fox fox fox")
        let result = ContentFindHighlighter.highlight(
            source,
            query: "fox",
            options: FindOptions(),
            currentOccurrence: 1
        )

        let colored = backgroundRuns(result)
        XCTAssertEqual(
            colored.filter { $0 == ContentFindHighlighter.currentColor }.count,
            1,
            "Exactly one match is the current (emphasized) color"
        )
        XCTAssertEqual(colored.filter { $0 == ContentFindHighlighter.matchColor }.count, 2)
    }

    /// Function: `highlight` — verifies the highlighted range covers the exact matched text.
    /// Input: "alpha BETA gamma"; query "beta" (case-insensitive). Output: the run carrying a
    /// background renders the substring "BETA".
    func testHighlightRangeCoversMatchedText() {
        let source = AttributedString("alpha BETA gamma")
        let result = ContentFindHighlighter.highlight(
            source,
            query: "beta",
            options: FindOptions(),
            currentOccurrence: 0
        )

        let highlightedText = result.runs
            .filter { $0.backgroundColor != nil }
            .map { String(result[$0.range].characters) }
            .joined()
        XCTAssertEqual(highlightedText, "BETA", "The highlight must land on the matched substring")
    }

    /// Function: `highlight` with an empty query. Output: unchanged (no backgrounds).
    func testEmptyQueryIsPassThrough() {
        let source = AttributedString("nothing to do")
        let result = ContentFindHighlighter.highlight(source, query: "", options: FindOptions(), currentOccurrence: nil)
        XCTAssertTrue(backgroundRuns(result).isEmpty)
    }

    /// Function: `highlight` with no matches. Output: unchanged (no backgrounds).
    func testNoMatchIsPassThrough() {
        let source = AttributedString("nothing here")
        let result = ContentFindHighlighter.highlight(
            source,
            query: "xyz",
            options: FindOptions(),
            currentOccurrence: nil
        )
        XCTAssertTrue(backgroundRuns(result).isEmpty)
    }

    /// Function: `highlight` over multi-byte text (index mapping must use character offsets).
    /// Input: "café au lait, café"; query "café". Output: 2 highlighted runs, each rendering "café".
    func testUnicodeMappingIsCorrect() {
        let source = AttributedString("café au lait, café")
        let result = ContentFindHighlighter.highlight(
            source,
            query: "café",
            options: FindOptions(),
            currentOccurrence: nil
        )

        let highlighted = result.runs
            .filter { $0.backgroundColor != nil }
            .map { String(result[$0.range].characters) }
        XCTAssertEqual(highlighted, ["café", "café"], "Unicode ranges must map correctly")
    }
}

/// FindMatchingTests - Unit tests for the FindMatching engine (C2)
///
/// Proves the shared matcher used by both find bars: default case-insensitivity,
/// each opt-in toggle (case-sensitive, whole-word, regex), and the negative self-tests
/// (invalid regex, empty query, zero-length matches) that must fail closed.

import XCTest
@testable import ViewerUI

final class FindMatchingTests: XCTestCase {

    // MARK: - Default (case-insensitive literal)

    /// Function: `matchRanges(in:query:options:)` with default options.
    /// Input: text containing "Note"/"note"/"NOTE"; query "note" (String); default options.
    /// Output: 3 ranges (Int count) — matching is case-insensitive by default.
    func testDefaultIsCaseInsensitive() {
        let text = "Note note NOTE noTe"
        let ranges = FindMatching.matchRanges(in: text, query: "note", options: FindOptions())
        XCTAssertEqual(ranges.count, 4, "Default matching should be case-insensitive")
    }

    /// Function: `matchRanges`. Input: empty query. Output: no ranges (0).
    func testEmptyQueryReturnsNoMatches() {
        XCTAssertTrue(FindMatching.matchRanges(in: "anything", query: "", options: FindOptions()).isEmpty)
    }

    // MARK: - Case sensitivity (opt-in)

    /// Function: `matchRanges` with `caseSensitive = true`.
    /// Input: "Note note NOTE"; query "Note". Output: exactly 1 range (only the exact-case hit).
    func testCaseSensitiveMatchesExactCaseOnly() {
        let ranges = FindMatching.matchRanges(
            in: "Note note NOTE",
            query: "Note",
            options: FindOptions(caseSensitive: true)
        )
        XCTAssertEqual(ranges.count, 1, "Case-sensitive search should match only the exact case")
    }

    // MARK: - Whole word (opt-in)

    /// Function: `matchRanges` with `wholeWord = true`.
    /// Input: "cat category cat."; query "cat". Output: 2 ranges (the standalone words, not "category").
    func testWholeWordExcludesSubstrings() {
        let ranges = FindMatching.matchRanges(
            in: "cat category cat.",
            query: "cat",
            options: FindOptions(wholeWord: true)
        )
        XCTAssertEqual(ranges.count, 2, "Whole-word search should skip the substring inside 'category'")
    }

    /// Function: `matchRanges` without whole word (control for the test above).
    /// Input: "cat category cat."; query "cat". Output: 3 ranges (includes the substring).
    func testSubstringMatchesWhenWholeWordOff() {
        let ranges = FindMatching.matchRanges(
            in: "cat category cat.",
            query: "cat",
            options: FindOptions()
        )
        XCTAssertEqual(ranges.count, 3)
    }

    // MARK: - Regex (opt-in)

    /// Function: `matchRanges` with `useRegex = true`.
    /// Input: "a1 b2 c3"; pattern "[a-z][0-9]". Output: 3 ranges.
    func testRegexMatches() {
        let ranges = FindMatching.matchRanges(
            in: "a1 b2 c3",
            query: "[a-z][0-9]",
            options: FindOptions(useRegex: true)
        )
        XCTAssertEqual(ranges.count, 3)
    }

    /// Function: `matchRanges` regex + default case-insensitivity.
    /// Input: "ABC abc"; pattern "abc". Output: 2 (regex honors the case-insensitive default).
    func testRegexIsCaseInsensitiveByDefault() {
        let ranges = FindMatching.matchRanges(
            in: "ABC abc",
            query: "abc",
            options: FindOptions(useRegex: true)
        )
        XCTAssertEqual(ranges.count, 2)
    }

    /// Negative self-test. Function: `matchRanges` + `isValidRegex` with an invalid pattern.
    /// Input: unbalanced "[" pattern, regex on. Output: no ranges AND isValidRegex == false.
    func testInvalidRegexFailsClosed() {
        let options = FindOptions(useRegex: true)
        XCTAssertTrue(FindMatching.matchRanges(in: "text", query: "[", options: options).isEmpty,
                      "An invalid regex must produce no matches, not crash")
        XCTAssertFalse(FindMatching.isValidRegex("[", options: options),
                       "isValidRegex must report an uncompilable pattern as invalid")
    }

    /// Function: `isValidRegex` for literal mode and empty query. Output: always true.
    func testIsValidRegexTrueForLiteralOrEmpty() {
        XCTAssertTrue(FindMatching.isValidRegex("[", options: FindOptions()), "Literal mode never invalid")
        XCTAssertTrue(FindMatching.isValidRegex("", options: FindOptions(useRegex: true)), "Empty query never invalid")
    }

    /// Negative self-test. Function: `matchRanges` with a zero-width regex.
    /// Input: "abc"; pattern "x*" (matches empty string everywhere), regex on.
    /// Output: zero ranges — empty matches are discarded so highlighting can't loop.
    func testZeroLengthMatchesAreDiscarded() {
        let ranges = FindMatching.matchRanges(
            in: "abc",
            query: "x*",
            options: FindOptions(useRegex: true)
        )
        XCTAssertTrue(ranges.isEmpty, "Zero-length matches must be filtered out")
    }

    // MARK: - Unicode

    /// Function: `matches(in:query:options:)` (String.Index variant) over multi-byte text.
    /// Input: "café Café CAFÉ"; query "café". Output: 3 ranges convertible to String ranges.
    func testUnicodeCaseInsensitive() {
        let text = "café Café CAFÉ"
        let ranges = FindMatching.matches(in: text, query: "café", options: FindOptions())
        XCTAssertEqual(ranges.count, 3)
        for range in ranges {
            XCTAssertEqual(text[range].lowercased(), "café")
        }
    }
}

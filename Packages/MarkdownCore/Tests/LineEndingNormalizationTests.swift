/// LineEndingNormalizationTests - Regression tests for CRLF handling in MarkdownParser
///
/// Covers the crash where opening a CRLF document containing HTML-block-like lines
/// (e.g. an Excel-exported CSV whose cells begin with "<tag>") aborted with
/// `Fatal error: Index out of range` inside swift-markdown's RangeAdjuster, and
/// confirms line endings are normalized to LF in the stored document.

import XCTest
@testable import MarkdownCore

final class LineEndingNormalizationTests: XCTestCase {

    private func reference(ext: String) -> DocumentReference {
        DocumentReference(
            url: URL(fileURLWithPath: "/tmp/sample.\(ext)"),
            lastModified: Date(),
            fileSize: 0
        )
    }

    /// Function under test: `MarkdownParser.parseDocument(content:reference:)`.
    /// Input: CRLF-terminated CSV-like text whose cells start with HTML tags
    ///   ("<div>", "<span>") — the exact shape that crashed swift-markdown (String).
    /// Output: a `DocumentModel` (parsing completes without trapping); this test fails
    ///   only if the process crashes or an error is thrown.
    func testCRLFHTMLBlockDoesNotCrash() async throws {
        let content = "col1,col2\r\n<div>,alpha\r\n<span>,beta\r\n\"Smith, John\",40\r\n"
        let parser = MarkdownParser()
        let document = try await parser.parseDocument(content: content, reference: reference(ext: "csv"))
        XCTAssertEqual(document.format, .plainText)
    }

    /// Function under test: `parseDocument` line-ending normalization.
    /// Input: text mixing CRLF and a lone CR (String).
    /// Output: `DocumentModel.content` contains neither "\r\n" nor "\r" (LF only).
    func testStoredContentIsNormalizedToLF() async throws {
        let content = "line one\r\nline two\rline three\n"
        let parser = MarkdownParser()
        let document = try await parser.parseDocument(content: content, reference: reference(ext: "md"))
        XCTAssertFalse(document.content.contains("\r"), "Stored content must not contain carriage returns")
        XCTAssertEqual(document.content, "line one\nline two\nline three\n")
    }

    /// Function under test: `parseDocument` with already-LF content.
    /// Input: pure LF text (String). Output: content is byte-identical (no spurious rewrite).
    func testLFContentIsUnchanged() async throws {
        let content = "# Title\n\nA paragraph.\n"
        let parser = MarkdownParser()
        let document = try await parser.parseDocument(content: content, reference: reference(ext: "md"))
        XCTAssertEqual(document.content, content)
    }
}

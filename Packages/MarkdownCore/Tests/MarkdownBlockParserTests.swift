// MarkdownBlockParserTests - Unit tests for the swift-markdown block model
//
// Validates that MarkdownBlockParser produces the block kinds, inline styling,
// source-line numbers, and scroll anchors the viewer depends on. These tests
// are the regression guard for the viewer's rendering rewrite: they lock the
// parsing contract (block types, plain text, anchors, line numbers) that the
// find machinery, line numbers, translation, and outline navigation rely on.

@testable import MarkdownCore
import XCTest

final class MarkdownBlockParserTests: XCTestCase {
    // MARK: - Headings

    /// Function: MarkdownBlockParser.parse (heading path)
    /// Input: single ATX heading string. Output: one .heading(level:1) block,
    /// plainText "Title", sourceLine 1.
    func testHeadingParsed() {
        let blocks = MarkdownBlockParser.parse("# Title")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .heading(level: 1))
        XCTAssertEqual(blocks[0].plainText, "Title")
        XCTAssertEqual(blocks[0].sourceLine, 1)
    }

    /// Function: MarkdownBlock.anchorID (heading)
    /// Input: heading with inline emphasis "## **Bold** Title". Output: anchor
    /// "heading-Bold Title" — markers stripped, matching the outline's title
    /// scheme so heading navigation resolves.
    func testHeadingAnchorMatchesPlainTitle() {
        let blocks = MarkdownBlockParser.parse("## **Bold** Title")
        XCTAssertEqual(blocks[0].plainText, "Bold Title")
        XCTAssertEqual(blocks[0].anchorID, "heading-Bold Title")
    }

    // MARK: - Inline styling

    /// Function: MarkdownBlockParser.parse (inline styling)
    /// Input: paragraph mixing bold, italic and code. Output: runs carrying the
    /// corresponding style flags; concatenated plain text drops all markers.
    func testParagraphInlineStyles() {
        let blocks = MarkdownBlockParser.parse("A **b** _i_ `c`")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertEqual(blocks[0].plainText, "A b i c")

        let runs = blocks[0].runs
        XCTAssertTrue(runs.contains { $0.text == "b" && $0.isBold })
        XCTAssertTrue(runs.contains { $0.text == "i" && $0.isItalic })
        XCTAssertTrue(runs.contains { $0.text == "c" && $0.isCode })
    }

    /// Function: MarkdownBlockParser.parse (link path)
    /// Input: paragraph with a markdown link. Output: a run whose text is the
    /// link label and whose `link` is the destination.
    func testLinkRunCarriesDestination() {
        let blocks = MarkdownBlockParser.parse("See [docs](https://example.com).")
        let linkRun = blocks[0].runs.first { $0.link != nil }
        XCTAssertEqual(linkRun?.text, "docs")
        XCTAssertEqual(linkRun?.link, "https://example.com")
        XCTAssertEqual(blocks[0].plainText, "See docs.")
    }

    /// Function: MarkdownBlockParser.parse (strikethrough / GFM)
    /// Input: paragraph with ~~struck~~ text. Output: a run flagged strikethrough.
    func testStrikethrough() {
        let blocks = MarkdownBlockParser.parse("~~gone~~ here")
        XCTAssertTrue(blocks[0].runs.contains { $0.text == "gone" && $0.isStrikethrough })
    }

    // MARK: - Code blocks

    /// Function: MarkdownBlockParser.parse (fenced code)
    /// Input: fenced code block with a language. Output: .codeBlock(language:"swift"),
    /// code text without fences or trailing newline.
    func testFencedCodeBlock() {
        let blocks = MarkdownBlockParser.parse("```swift\nlet x = 1\n```")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .codeBlock(language: "swift"))
        XCTAssertEqual(blocks[0].code, "let x = 1")
    }

    // MARK: - Lists

    /// Function: MarkdownBlockParser.parse (unordered list)
    /// Input: two-item bullet list. Output: .unorderedList with two items, markers
    /// stripped.
    func testUnorderedList() {
        let blocks = MarkdownBlockParser.parse("- one\n- two")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .unorderedList)
        XCTAssertEqual(blocks[0].listItems.map { $0.plainText }, ["one", "two"])
    }

    /// Function: MarkdownBlockParser.parse (ordered list)
    /// Input: two-item numbered list. Output: .orderedList with two items.
    func testOrderedList() {
        let blocks = MarkdownBlockParser.parse("1. first\n2. second")
        XCTAssertEqual(blocks[0].kind, .orderedList)
        XCTAssertEqual(blocks[0].listItems.map { $0.plainText }, ["first", "second"])
    }

    // MARK: - Tables

    /// Function: MarkdownBlockParser.parse (GFM table)
    /// Input: a 2-column table with one body row. Output: .table with a header row
    /// and one body row; header cells "H1"/"H2", body cells "a"/"b".
    func testTable() {
        let md = "| H1 | H2 |\n| --- | --- |\n| a | b |"
        let blocks = MarkdownBlockParser.parse(md)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .table)
        XCTAssertEqual(blocks[0].tableRows.count, 2)
        XCTAssertEqual(blocks[0].tableRows[0].map { $0.plainText }, ["H1", "H2"])
        XCTAssertEqual(blocks[0].tableRows[1].map { $0.plainText }, ["a", "b"])
    }

    // MARK: - Thematic break

    /// Function: MarkdownBlockParser.parse (thematic break)
    /// Input: "---". Output: one .thematicBreak block.
    func testThematicBreak() {
        let blocks = MarkdownBlockParser.parse("above\n\n---\n\nbelow")
        XCTAssertTrue(blocks.contains { $0.kind == .thematicBreak })
    }

    // MARK: - Source lines / ordering

    /// Function: MarkdownBlockParser.parse (source line tracking)
    /// Input: heading on line 1, paragraph on line 3. Output: blocks report
    /// sourceLine 1 and 3 respectively (1-based).
    func testSourceLinesTracked() {
        let blocks = MarkdownBlockParser.parse("# Head\n\nBody paragraph")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].sourceLine, 1)
        XCTAssertEqual(blocks[1].sourceLine, 3)
    }

    /// Function: MarkdownBlockParser.parse (empty input)
    /// Input: empty string. Output: [] (no blocks).
    func testEmptyInput() {
        XCTAssertTrue(MarkdownBlockParser.parse("").isEmpty)
    }

    // MARK: - Translatability

    /// Function: MarkdownBlock.isTranslatable
    /// Input: a paragraph and a code block. Output: paragraph translatable,
    /// code block not.
    func testIsTranslatable() {
        let para = MarkdownBlockParser.parse("Hello world")[0]
        let code = MarkdownBlockParser.parse("```\ncode\n```")[0]
        XCTAssertTrue(para.isTranslatable)
        XCTAssertFalse(code.isTranslatable)
    }
}

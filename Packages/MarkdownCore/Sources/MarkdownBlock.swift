// MarkdownBlock - Structured, source-located block model built from swift-markdown
//
// This is the single source of truth for the reader's block/inline structure.
// It replaces the hand-rolled tokenizers that previously lived in the SwiftUI
// viewer, so the viewer and MarkdownCore agree on how markdown is parsed.
//
// The model is deliberately UI-agnostic (no SwiftUI import): inline styling is
// expressed as semantic flags on `InlineRun`, and the view layer maps those to
// fonts/colors. Every block carries its 1-based source line so the viewer can
// keep line numbers, scroll anchors, and per-block translation working.

import Foundation
import Markdown

// MARK: - Inline Run

/// A contiguous run of inline text sharing the same styling.
///
/// `text` is the rendered (marker-free) text; concatenating every run's `text`
/// yields the block's plain text, which the find machinery matches against.
public struct InlineRun: Sendable, Equatable {
    public var text: String
    public var isBold: Bool
    public var isItalic: Bool
    public var isCode: Bool
    public var isStrikethrough: Bool
    public var link: String?

    public init(
        text: String,
        isBold: Bool = false,
        isItalic: Bool = false,
        isCode: Bool = false,
        isStrikethrough: Bool = false,
        link: String? = nil
    ) {
        self.text = text
        self.isBold = isBold
        self.isItalic = isItalic
        self.isCode = isCode
        self.isStrikethrough = isStrikethrough
        self.link = link
    }
}

public extension Array where Element == InlineRun {
    /// Marker-free plain text of a run sequence (what find/translation operate on).
    var plainText: String {
        map(\.text).joined()
    }
}

// MARK: - Markdown Block

/// A top-level renderable block with its source location.
public struct MarkdownBlock: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case heading(level: Int)
        case paragraph
        case codeBlock(language: String?)
        case blockquote
        case unorderedList
        case orderedList
        case table
        case thematicBreak
    }

    /// Index of this block within the parsed document (also its render id).
    public let id: Int
    public let kind: Kind
    /// 1-based line in the (LF-normalized) source where the block begins.
    public let sourceLine: Int

    /// Inline content for heading / paragraph / blockquote blocks.
    public let runs: [InlineRun]
    /// Raw code text for `codeBlock` (fences stripped, no trailing newline).
    public let code: String
    /// One run-sequence per list item (`unorderedList` / `orderedList`).
    public let listItems: [[InlineRun]]
    /// Rows → cells → runs for `table` (row 0 is the header row).
    public let tableRows: [[[InlineRun]]]

    public init(
        id: Int,
        kind: Kind,
        sourceLine: Int,
        runs: [InlineRun] = [],
        code: String = "",
        listItems: [[InlineRun]] = [],
        tableRows: [[[InlineRun]]] = []
    ) {
        self.id = id
        self.kind = kind
        self.sourceLine = sourceLine
        self.runs = runs
        self.code = code
        self.listItems = listItems
        self.tableRows = tableRows
    }

    /// Marker-free plain text of the block's primary inline content.
    public var plainText: String {
        runs.plainText
    }

    /// Stable SwiftUI/scroll anchor. Headings use their title (matching the
    /// document outline's `"heading-<title>"` scheme) so outline navigation
    /// resolves; every other block anchors to its source line.
    public var anchorID: String {
        switch kind {
        case .heading:
            return "heading-\(plainText)"
        default:
            return "line-\(sourceLine)"
        }
    }

    /// Whether this block's text should be offered to the translator.
    public var isTranslatable: Bool {
        switch kind {
        case .codeBlock, .thematicBreak:
            return false
        case .table:
            return tableRows
                .contains { row in row.contains { !$0.plainText.trimmingCharacters(in: .whitespaces).isEmpty } }
        case .unorderedList, .orderedList:
            return listItems.contains { !$0.plainText.trimmingCharacters(in: .whitespaces).isEmpty }
        default:
            return !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - Parser

/// Parses markdown into `[MarkdownBlock]` using swift-markdown's AST.
public enum MarkdownBlockParser {
    /// Parse `content` into top-level blocks.
    ///
    /// Input: LF-normalized markdown/plain text (any length).
    /// Output: blocks in document order, each with a 1-based `sourceLine`.
    public static func parse(_ content: String) -> [MarkdownBlock] {
        guard !content.isEmpty else { return [] }
        let document = Document(parsing: content)
        var blocks: [MarkdownBlock] = []
        for child in document.children {
            if let block = makeBlock(from: child, id: blocks.count) {
                blocks.append(block)
            }
        }
        return blocks
    }

    private static func sourceLine(of markup: Markup) -> Int {
        markup.range?.lowerBound.line ?? 1
    }

    private static func makeBlock(from markup: Markup, id: Int) -> MarkdownBlock? {
        let line = sourceLine(of: markup)

        switch markup {
        case let heading as Heading:
            return MarkdownBlock(
                id: id,
                kind: .heading(level: min(heading.level, 6)),
                sourceLine: line,
                runs: inlineRuns(of: heading)
            )

        case let paragraph as Paragraph:
            return MarkdownBlock(
                id: id,
                kind: .paragraph,
                sourceLine: line,
                runs: inlineRuns(of: paragraph)
            )

        case let codeBlock as CodeBlock:
            let language = codeBlock.language?.trimmingCharacters(in: .whitespaces)
            var code = codeBlock.code
            if code.hasSuffix("\n") {
                code.removeLast()
            }
            return MarkdownBlock(
                id: id,
                kind: .codeBlock(language: (language?.isEmpty ?? true) ? nil : language),
                sourceLine: line,
                code: code
            )

        case let blockQuote as BlockQuote:
            return MarkdownBlock(
                id: id,
                kind: .blockquote,
                sourceLine: line,
                runs: blockRuns(of: blockQuote)
            )

        case let list as UnorderedList:
            return MarkdownBlock(
                id: id,
                kind: .unorderedList,
                sourceLine: line,
                listItems: listItemRuns(of: list)
            )

        case let list as OrderedList:
            return MarkdownBlock(
                id: id,
                kind: .orderedList,
                sourceLine: line,
                listItems: listItemRuns(of: list)
            )

        case let table as Table:
            return MarkdownBlock(
                id: id,
                kind: .table,
                sourceLine: line,
                tableRows: tableCellRuns(of: table)
            )

        case is ThematicBreak:
            return MarkdownBlock(id: id, kind: .thematicBreak, sourceLine: line)

        case let html as HTMLBlock:
            // Render raw HTML blocks as plain paragraph text (the reader does not
            // execute HTML). Keeps otherwise-invisible content visible.
            let text = html.rawHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return MarkdownBlock(id: id, kind: .paragraph, sourceLine: line, runs: [InlineRun(text: text)])

        default:
            // Fallback: treat any other block as a paragraph of its plain text.
            let text = (markup as? BlockMarkup).map { plainText(of: $0) } ?? ""
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return MarkdownBlock(id: id, kind: .paragraph, sourceLine: line, runs: [InlineRun(text: text)])
        }
    }

    // MARK: Inline extraction

    /// Runs for a single inline-containing block (heading / paragraph).
    private static func inlineRuns(of markup: Markup) -> [InlineRun] {
        var runs: [InlineRun] = []
        for child in markup.children {
            appendRuns(
                from: child,
                into: &runs,
                bold: false,
                italic: false,
                code: false,
                strike: false,
                link: nil
            )
        }
        return coalesce(runs)
    }

    /// Runs for a blockquote: concatenate child block runs, newline-separated.
    private static func blockRuns(of markup: Markup) -> [InlineRun] {
        var runs: [InlineRun] = []
        for (index, child) in markup.children.enumerated() {
            if index > 0 {
                runs.append(InlineRun(text: "\n"))
            }
            if child is Paragraph || child is Heading {
                runs.append(contentsOf: inlineRuns(of: child))
            } else {
                runs.append(contentsOf: blockRuns(of: child))
            }
        }
        return coalesce(runs)
    }

    private static func listItemRuns(of list: Markup) -> [[InlineRun]] {
        var items: [[InlineRun]] = []
        for case let item as ListItem in list.children {
            // Use the item's first paragraph as its text (flat-list behavior,
            // matching the previous renderer). Nested blocks are ignored here.
            if let paragraph = item.children.compactMap({ $0 as? Paragraph }).first {
                items.append(inlineRuns(of: paragraph))
            } else {
                items.append([InlineRun(text: plainText(of: item))])
            }
        }
        return items
    }

    private static func tableCellRuns(of table: Table) -> [[[InlineRun]]] {
        var rows: [[[InlineRun]]] = []
        rows.append(table.head.cells.map { inlineRuns(of: $0) })
        for row in table.body.rows {
            rows.append(row.cells.map { inlineRuns(of: $0) })
        }
        return rows
    }

    /// Depth-first inline walk, accumulating styling from wrapping markup.
    private static func appendRuns(
        from markup: Markup,
        into runs: inout [InlineRun],
        bold: Bool,
        italic: Bool,
        code: Bool,
        strike: Bool,
        link: String?
    ) {
        switch markup {
        case let text as Markdown.Text:
            runs.append(InlineRun(
                text: text.string,
                isBold: bold,
                isItalic: italic,
                isCode: code,
                isStrikethrough: strike,
                link: link
            ))
        case let inlineCode as InlineCode:
            runs.append(InlineRun(
                text: inlineCode.code,
                isBold: bold,
                isItalic: italic,
                isCode: true,
                isStrikethrough: strike,
                link: link
            ))
        case let inlineHTML as InlineHTML:
            runs.append(InlineRun(
                text: inlineHTML.rawHTML,
                isBold: bold,
                isItalic: italic,
                isCode: code,
                isStrikethrough: strike,
                link: link
            ))
        case is SoftBreak:
            // Preserve the source's line structure (previous renderer joined
            // wrapped lines with "\n"), so find offsets stay stable.
            runs.append(InlineRun(text: "\n"))
        case is LineBreak:
            runs.append(InlineRun(text: "\n"))
        case let emphasis as Emphasis:
            for child in emphasis.children {
                appendRuns(
                    from: child,
                    into: &runs,
                    bold: bold,
                    italic: true,
                    code: code,
                    strike: strike,
                    link: link
                )
            }
        case let strong as Strong:
            for child in strong.children {
                appendRuns(
                    from: child,
                    into: &runs,
                    bold: true,
                    italic: italic,
                    code: code,
                    strike: strike,
                    link: link
                )
            }
        case let strikethrough as Strikethrough:
            for child in strikethrough.children {
                appendRuns(
                    from: child,
                    into: &runs,
                    bold: bold,
                    italic: italic,
                    code: code,
                    strike: true,
                    link: link
                )
            }
        case let anchor as Link:
            let destination = anchor.destination ?? link
            for child in anchor.children {
                appendRuns(
                    from: child,
                    into: &runs,
                    bold: bold,
                    italic: italic,
                    code: code,
                    strike: strike,
                    link: destination
                )
            }
        case let image as Image:
            // Show the alt text for images (no remote loading in the reader).
            let alt = image.plainText
            if !alt.isEmpty {
                runs.append(InlineRun(
                    text: alt,
                    isBold: bold,
                    isItalic: italic,
                    isCode: code,
                    isStrikethrough: strike,
                    link: link
                ))
            }
        default:
            for child in markup.children {
                appendRuns(
                    from: child,
                    into: &runs,
                    bold: bold,
                    italic: italic,
                    code: code,
                    strike: strike,
                    link: link
                )
            }
        }
    }

    /// Merges adjacent runs that share identical styling (keeps output compact
    /// and deterministic for tests).
    private static func coalesce(_ runs: [InlineRun]) -> [InlineRun] {
        var result: [InlineRun] = []
        for run in runs where !run.text.isEmpty {
            if var last = result.last,
               last.isBold == run.isBold, last.isItalic == run.isItalic,
               last.isCode == run.isCode, last.isStrikethrough == run.isStrikethrough,
               last.link == run.link {
                last.text += run.text
                result[result.count - 1] = last
            } else {
                result.append(run)
            }
        }
        return result
    }

    private static func plainText(of markup: Markup) -> String {
        if let text = markup as? Markdown.Text {
            return text.string
        }
        return markup.children.map { plainText(of: $0) }.joined()
    }
}

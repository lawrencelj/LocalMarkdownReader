import MarkdownCore

/// Maps source-editor line selections to the rendered content row that represents them.
enum ContentLineSynchronizer {
    /// Returns the source line used by the rendered block containing `line`.
    ///
    /// Input: a positive 1-based source line and an ordered block list.
    /// Output: the containing block's 1-based source line, or `nil` when no block precedes it.
    static func containingBlockSourceLine(for line: Int, in blocks: [MarkdownBlock]) -> Int? {
        guard line > 0 else { return nil }
        return blocks.last(where: { $0.sourceLine <= line })?.sourceLine
    }

    /// Returns the exact rendered row line when a block has one row per source line.
    ///
    /// Input: a positive 1-based source line and an ordered block list.
    /// Output: an exact list/table row line when available; otherwise the block's start line.
    static func renderedAnchorLine(for line: Int, in blocks: [MarkdownBlock]) -> Int? {
        guard line > 0,
              let block = blocks.last(where: { $0.sourceLine <= line }) else { return nil }

        switch block.kind {
        case .unorderedList, .orderedList:
            let lastLine = block.sourceLine + block.listItems.count - 1
            return line <= lastLine ? line : block.sourceLine
        case .table:
            for rowIndex in block.tableRows.indices {
                let rowLine = rowIndex == 0 ? block.sourceLine : block.sourceLine + rowIndex + 1
                if rowLine == line { return line }
            }
            return block.sourceLine
        default:
            return block.sourceLine
        }
    }

    /// Returns whether a source line belongs to a block-level rendered row.
    ///
    /// Input: a positive focused line, a block start line, and the next block's start line.
    /// Output: `true` when the focused line falls in this block's source range.
    static func contains(
        focusedLine: Int?,
        blockSourceLine: Int,
        nextBlockSourceLine: Int?
    ) -> Bool {
        guard let focusedLine, focusedLine >= blockSourceLine else { return false }
        let endLine = nextBlockSourceLine.map { $0 - 1 } ?? Int.max
        return focusedLine <= endLine
    }
}

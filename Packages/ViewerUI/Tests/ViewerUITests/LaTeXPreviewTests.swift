import XCTest
@testable import ViewerUI

final class LaTeXPreviewTests: XCTestCase {
    func testParserBuildsRenderedBlocks() {
        let content = #"""
        \documentclass{article}
        \title{Preview Test}
        \author{Ada}
        \begin{document}
        \maketitle
        \section{Introduction}
        A paragraph with \textbf{bold text} and $\alpha + \beta$.

        \begin{itemize}
        \item First
        \item Second
        \end{itemize}

        \begin{equation}
        E = mc^2
        \end{equation}
        \end{document}
        """#

        let blocks = LaTeXParser.parse(content)

        XCTAssertTrue(blocks.contains { $0.kind == .title && $0.content == "Preview Test" })
        XCTAssertTrue(blocks.contains { $0.kind == .section(level: 1) && $0.content == "Introduction" })
        XCTAssertTrue(blocks.contains { $0.kind == .paragraph && $0.content.contains("bold text") })
        XCTAssertTrue(blocks.contains { $0.kind == .unorderedList && $0.items == ["First", "Second"] })
        XCTAssertTrue(blocks.contains { $0.kind == .equation && $0.content.contains("E = mc^2") })
    }

    func testMathFormatterMakesCommonCommandsReadable() {
        let rendered = LaTeXInlineFormatter.mathText(
            from: #"\frac{-b \pm \sqrt{d}}{2a} \rightarrow \infty"#
        )

        XCTAssertTrue(rendered.contains("(-b ± √(d))/(2a)"))
        XCTAssertTrue(rendered.contains("→"))
        XCTAssertTrue(rendered.contains("∞"))
    }
}

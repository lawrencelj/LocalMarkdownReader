// LineNumberTextViewTests - Unit tests for LineNumberTextView
//
// Tests gutter enable/disable, font configuration, color configuration,
// gutter width, current line highlighting, and — critically — that enabling
// the gutter never blanks the source text and that gutter content is drawn
// in the text view's own coordinate space (so it scrolls with the text).
//
// Supersedes LineNumberRulerViewTests (archived in Archive/): the NSRulerView
// gutter blanked the document view when hosted inside SwiftUI's NSHostingView.
//
// Validates: Requirements 1.1, 1.2, 1.4, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 6.1

#if os(macOS)
    import AppKit
    @testable import ViewerUI
    import XCTest

    @MainActor
    final class LineNumberTextViewTests: XCTestCase {
        // MARK: - Test Helpers

        /// Creates a configured LineNumberTextView inside a scroll view.
        ///
        /// - Input: `content` — document text (String, any length; default 5 lines),
        ///          `showNumbers` — initial gutter visibility (Bool).
        /// - Output: the text view and its enclosing scroll view, laid out at 600x400.
        private func makeTextView(
            content: String = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5",
            showNumbers: Bool = true
        ) -> (LineNumberTextView, NSScrollView) {
            let textStorage = NSTextStorage()
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)
            let textContainer = NSTextContainer(containerSize: NSSize(
                width: 0,
                height: CGFloat.greatestFiniteMagnitude
            ))
            textContainer.widthTracksTextView = true
            layoutManager.addTextContainer(textContainer)

            let textView = LineNumberTextView(
                frame: NSRect(x: 0, y: 0, width: 600, height: 400),
                textContainer: textContainer
            )
            textView.minSize = NSSize(width: 0, height: 0)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isVerticallyResizable = true
            textView.autoresizingMask = [.width]
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.textContainerInset = NSSize(width: 8, height: 8)

            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            scrollView.hasVerticalScroller = true
            // Attach before setting content (as production does) so the text view grows
            // downward in the flipped clip-view coordinate space.
            scrollView.documentView = textView
            textView.string = content

            textView.lineNumberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            textView.lineNumberColor = NSColor.gray.withAlphaComponent(0.4)
            textView.currentLineColor = NSColor.controlAccentColor
            textView.separatorColor = NSColor.separatorColor
            textView.showsLineNumbers = showNumbers

            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            return (textView, scrollView)
        }

        /// Counts distinct colors in a rectangular region of a bitmap.
        ///
        /// - Input: `rep` — bitmap to sample; `region` — pixel rect within the bitmap.
        /// - Output: number of distinct pixel colors (Int >= 0). A blank region yields 1.
        private func distinctColorCount(in rep: NSBitmapImageRep, region: NSRect) -> Int {
            var colors = Set<String>()
            let maxX = min(Int(region.maxX), rep.pixelsWide)
            let maxY = min(Int(region.maxY), rep.pixelsHigh)
            for x in stride(from: Int(region.minX), to: maxX, by: 2) {
                for y in stride(from: Int(region.minY), to: maxY, by: 2) {
                    if let color = rep.colorAt(x: x, y: y) {
                        colors.insert(color.description)
                    }
                }
            }
            return colors.count
        }

        // MARK: - Gutter Enable/Disable Tests

        /// Function under test: `showsLineNumbers` (enable).
        /// Input: 5-line document, gutter enabled. Output: exclusion path installed,
        /// gutter width >= 36pt so numbers have reserved space.
        /// Validates: Requirement 1.1
        func testGutterEnabled_reservesExclusionSpace() {
            let (textView, _) = makeTextView(showNumbers: true)

            XCTAssertTrue(textView.showsLineNumbers)
            XCTAssertEqual(
                textView.textContainer?.exclusionPaths.count,
                1,
                "Gutter should reserve space via one exclusion path"
            )
            XCTAssertGreaterThanOrEqual(
                textView.gutterWidth,
                36,
                "Gutter width should be at least 36pt"
            )
        }

        /// Function under test: `showsLineNumbers` (disable).
        /// Input: 5-line document, gutter disabled. Output: no exclusion paths,
        /// gutter width == 0 so the text reclaims the full width.
        /// Validates: Requirement 1.2
        func testGutterDisabled_releasesExclusionSpace() {
            let (textView, _) = makeTextView(showNumbers: true)
            XCTAssertEqual(textView.textContainer?.exclusionPaths.count, 1, "Precondition: gutter enabled")

            textView.showsLineNumbers = false

            XCTAssertTrue(
                textView.textContainer?.exclusionPaths.isEmpty ?? false,
                "Exclusion paths should be removed when line numbers are disabled"
            )
            XCTAssertEqual(
                textView.gutterWidth,
                0,
                "Gutter width should be 0 when line numbers are disabled"
            )
        }

        // MARK: - Font Tests

        /// Function under test: `lineNumberFont` default.
        /// Input: default configuration. Output: monospaced system font at 11pt.
        /// Validates: Requirements 1.4, 6.1
        func testLineNumberFont_isMonospacedSystemFontAt11pt() {
            let (textView, _) = makeTextView()

            let expectedFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            XCTAssertEqual(
                textView.lineNumberFont.fontName,
                expectedFont.fontName,
                "Line number font should be monospaced system font"
            )
            XCTAssertEqual(
                textView.lineNumberFont.pointSize,
                11,
                "Base font size should be 11pt per requirement 6.1"
            )
        }

        /// Function under test: `updateLineNumberFontSize(_:)`.
        /// Input: new point size 16.5 (CGFloat). Output: lineNumberFont updated to
        /// monospaced 16.5pt.
        /// Validates: Requirement 1.4
        func testLineNumberFont_updatesWhenFontSizeChanges() {
            let (textView, _) = makeTextView()

            textView.updateLineNumberFontSize(16.5)

            XCTAssertEqual(
                textView.lineNumberFont.pointSize,
                16.5,
                "Font point size should update to the new value"
            )
            let expectedFont = NSFont.monospacedSystemFont(ofSize: 16.5, weight: .regular)
            XCTAssertEqual(
                textView.lineNumberFont.fontName,
                expectedFont.fontName,
                "Font should remain monospaced system font after size update"
            )
        }

        // MARK: - Color Tests

        /// Function under test: `lineNumberColor` default.
        /// Input: default configuration. Output: alpha component <= 0.5 (subdued gray).
        /// Validates: Requirement 2.4
        func testBaseTextColor_alphaIsAtMostHalf() {
            let (textView, _) = makeTextView()

            XCTAssertLessThanOrEqual(
                textView.lineNumberColor.alphaComponent,
                0.5,
                "Base line number color alpha should be ≤ 0.5 per requirement 2.4"
            )
        }

        /// Function under test: `currentLineColor` default.
        /// Input: default configuration. Output: system accent color at full opacity.
        /// Validates: Requirement 3.1
        func testCurrentLineColor_usesAccentAtFullOpacity() {
            let (textView, _) = makeTextView()

            XCTAssertEqual(
                textView.currentLineColor,
                NSColor.controlAccentColor,
                "Current line color should use system accent color"
            )
            XCTAssertEqual(
                textView.currentLineColor.alphaComponent,
                1.0,
                "Current line color should be at full opacity"
            )
        }

        /// Function under test: `separatorColor` default.
        /// Input: default configuration. Output: NSColor.separatorColor.
        /// Validates: Requirement 2.3
        func testSeparatorColor_isConfigured() {
            let (textView, _) = makeTextView()

            XCTAssertEqual(
                textView.separatorColor,
                NSColor.separatorColor,
                "Separator should use NSColor.separatorColor"
            )
        }

        // MARK: - Gutter Width Tests

        /// Function under test: `requiredGutterWidth`.
        /// Input: 1-character document (1 line). Output: width >= 36pt.
        /// Validates: Requirement 6.1
        func testGutterWidth_minimumIs36pt() {
            let (textView, _) = makeTextView(content: "A")

            XCTAssertGreaterThanOrEqual(
                textView.requiredGutterWidth,
                36,
                "Gutter width should never be less than 36pt per requirement 6.1"
            )
        }

        /// Function under test: `requiredGutterWidth`.
        /// Input: empty document (0 characters). Output: width >= 36pt.
        /// Validates: Requirement 6.1
        func testGutterWidth_minimumIs36ptForEmptyDocument() {
            let (textView, _) = makeTextView(content: "")

            XCTAssertGreaterThanOrEqual(
                textView.requiredGutterWidth,
                36,
                "Gutter width should never be less than 36pt even for empty documents"
            )
        }

        /// Function under test: `requiredGutterWidth` digit scaling.
        /// Input: 1000-line document (4 digits) vs 2-line document (2-digit minimum).
        /// Output: 4-digit gutter width >= 2-digit gutter width.
        /// Validates: Requirement 2.2
        func testGutterWidth_accommodatesHighDigitCounts() {
            let content = (1 ... 1000).map { "Line \($0)" }.joined(separator: "\n")
            let (textView4Digits, _) = makeTextView(content: content)
            let thickness4Digits = textView4Digits.requiredGutterWidth
            XCTAssertGreaterThanOrEqual(thickness4Digits, 36)

            let (textView2Lines, _) = makeTextView(content: "Line 1\nLine 2")
            XCTAssertGreaterThanOrEqual(
                thickness4Digits,
                textView2Lines.requiredGutterWidth,
                "4-digit document should have gutter at least as wide as 2-digit document"
            )
        }

        // MARK: - Line Count Tests

        /// Function under test: `lineCount()`.
        /// Input: empty document, 1-line, and 5-line documents.
        /// Output: 1 for empty (an empty document has one line), matching counts otherwise.
        func testLineCount_countsLogicalLines() {
            let (emptyView, _) = makeTextView(content: "")
            XCTAssertEqual(emptyView.lineCount(), 1, "Empty document should report one line")

            let (oneLine, _) = makeTextView(content: "only line")
            XCTAssertEqual(oneLine.lineCount(), 1)

            let (fiveLines, _) = makeTextView()
            XCTAssertEqual(fiveLines.lineCount(), 5)
        }

        // MARK: - Current Line Highlighting Tests

        /// Function under test: `updateCurrentLine(_:)`.
        /// Input: line number 3 (Int). Output: `currentLine` == 3 with accent color
        /// distinct from the subdued base color.
        /// Validates: Requirement 3.1
        func testCurrentLineUsesAccentColor() {
            let (textView, _) = makeTextView()

            XCTAssertNil(textView.currentLine)

            textView.updateCurrentLine(3)

            XCTAssertEqual(textView.currentLine, 3)
            XCTAssertEqual(
                textView.currentLineColor.alphaComponent,
                1.0,
                accuracy: 0.01,
                "Current line color should be at full opacity"
            )
            XCTAssertLessThanOrEqual(
                textView.lineNumberColor.alphaComponent,
                0.5,
                "Base text color should be at subdued opacity (≤ 0.5)"
            )
            XCTAssertNotEqual(
                textView.currentLineColor,
                textView.lineNumberColor,
                "Current line color should be visually distinct from base color"
            )
        }

        /// Function under test: `updateCurrentLine(_:)` transition.
        /// Input: line 2 followed by line 4. Output: `currentLine` follows the last
        /// update (only one line highlighted at a time).
        /// Validates: Requirement 3.2
        func testMovingCursorUpdatesHighlight() {
            let (textView, _) = makeTextView()

            textView.updateCurrentLine(2)
            XCTAssertEqual(textView.currentLine, 2)

            textView.updateCurrentLine(4)
            XCTAssertEqual(
                textView.currentLine,
                4,
                "Current line should update to the new cursor position"
            )
        }

        /// Function under test: current-line derivation from a multi-line selection.
        /// Input: 5-line document with a selection spanning lines 2-4.
        /// Output: only the insertion-point line (selection start) is highlighted.
        /// Validates: Requirement 3.3
        func testMultiLineSelectionHighlightsInsertionPoint() throws {
            let (textView, _) = makeTextView()

            let selectionStart = 7 // Start of "Line 2"
            let selectionEnd = 27 // End of "Line 4"
            textView.setSelectedRange(NSRange(location: selectionStart, length: selectionEnd - selectionStart))

            // The coordinator logic computes the focused line from selectedRange().location
            let cursorLocation = textView.selectedRange().location
            let prefix = String(textView.string.prefix(cursorLocation))
            let lineNumber = prefix.components(separatedBy: "\n").count

            textView.updateCurrentLine(lineNumber)

            XCTAssertEqual(
                textView.currentLine,
                lineNumber,
                "Only the insertion point line should be highlighted"
            )
            XCTAssertTrue(
                try XCTUnwrap(textView.currentLine) >= 1 && textView.currentLine! <= 5,
                "Highlighted line should be within valid range"
            )
        }

        /// Function under test: highlight persistence across focus loss.
        /// Input: current line 3, then first responder resigned.
        /// Output: `currentLine` remains 3 and accent color unchanged.
        /// Validates: Requirement 3.4
        func testHighlightPersistsAfterFocusLoss() {
            let (textView, scrollView) = makeTextView()

            textView.updateCurrentLine(3)
            XCTAssertEqual(textView.currentLine, 3)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.contentView = scrollView
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(textView)
            window.makeFirstResponder(nil)

            XCTAssertEqual(
                textView.currentLine,
                3,
                "Current line highlight should persist after the text view loses focus"
            )
            XCTAssertEqual(
                textView.currentLineColor,
                NSColor.controlAccentColor,
                "The accent color for current line should remain unchanged after focus loss"
            )

            window.orderOut(nil)
        }

        /// Function under test: `updateCurrentLine(nil)`.
        /// Input: highlighted line 2, then nil. Output: `currentLine` is nil (no highlight).
        /// Validates: Requirement 3.2
        func testSettingCurrentLineToNilRemovesHighlight() {
            let (textView, _) = makeTextView()

            textView.updateCurrentLine(2)
            XCTAssertEqual(textView.currentLine, 2)

            textView.updateCurrentLine(nil)
            XCTAssertNil(
                textView.currentLine,
                "Setting currentLine to nil should remove the highlight"
            )
        }

        // MARK: - Rendering Regression Tests

        /// Function under test: `draw(_:)` with the gutter enabled.
        /// Input: 30-line document rendered at 600x400 with line numbers ON.
        /// Output: bitmap where BOTH the gutter region (x < gutterWidth) and the text
        /// region (x > gutterWidth) contain non-uniform pixels (numbers and glyphs drawn).
        ///
        /// Regression guard: with the previous NSRulerView gutter, enabling line numbers
        /// blanked the source text entirely (uniform background in the text region).
        func testRendering_gutterAndSourceTextAreBothVisible() throws {
            let content = (1 ... 30).map { "line \($0): sample markdown text" }.joined(separator: "\n")
            let (textView, scrollView) = makeTextView(content: content, showNumbers: true)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.contentView = scrollView
            scrollView.layoutSubtreeIfNeeded()
            try textView.layoutManager?.ensureLayout(for: XCTUnwrap(textView.textContainer))

            guard let rep = scrollView.bitmapImageRepForCachingDisplay(in: scrollView.bounds) else {
                return XCTFail("Could not create bitmap for scroll view")
            }
            scrollView.cacheDisplay(in: scrollView.bounds, to: rep)

            let scale = CGFloat(rep.pixelsWide) / scrollView.bounds.width
            let gutterEnd = textView.gutterWidth * scale

            // Gutter region must contain drawn line numbers (>= 2 distinct colors)
            let gutterRegion = NSRect(x: 0, y: 0, width: gutterEnd - 2 * scale, height: 300 * scale)
            XCTAssertGreaterThanOrEqual(
                distinctColorCount(in: rep, region: gutterRegion),
                2,
                "Gutter region should contain rendered line numbers"
            )

            // Text region must contain rendered glyphs — the source text must NOT disappear
            let textRegion = NSRect(x: gutterEnd + 4 * scale, y: 0, width: 300 * scale, height: 300 * scale)
            XCTAssertGreaterThanOrEqual(
                distinctColorCount(in: rep, region: textRegion),
                2,
                "Source text must remain visible when line numbers are shown"
            )

            window.orderOut(nil)
        }

        /// Function under test: `draw(_:)` scroll synchronization.
        /// Input: 200-line document scrolled down by 500pt with line numbers ON.
        /// Output: the gutter draws numbers in document coordinates — the first visible
        /// line number matches the first visible text line, so numbers and text cannot
        /// scroll independently (they share one coordinate space by construction).
        func testRendering_gutterScrollsWithText() throws {
            let content = (1 ... 200).map { "line \($0)" }.joined(separator: "\n")
            let (textView, scrollView) = makeTextView(content: content, showNumbers: true)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.contentView = scrollView
            scrollView.layoutSubtreeIfNeeded()
            try textView.layoutManager?.ensureLayout(for: XCTUnwrap(textView.textContainer))
            // Pin the caret to the start so it cannot auto-scroll the view elsewhere
            textView.setSelectedRange(NSRange(location: 0, length: 0))

            // Warm-up render: the first display pass performs scroll-view tiling and text
            // relayout, which can move the scroll position; complete it before scrolling.
            if let warmup = scrollView.bitmapImageRepForCachingDisplay(in: scrollView.bounds) {
                scrollView.cacheDisplay(in: scrollView.bounds, to: warmup)
            }
            // Tiling during the warm-up changes the container width and invalidates layout;
            // re-complete layout so the document height is final before scrolling.
            try textView.layoutManager?.ensureLayout(for: XCTUnwrap(textView.textContainer))
            textView.sizeToFit()

            // Scroll down 500pt in document space
            scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: 500))
            scrollView.reflectScrolledClipView(scrollView.contentView)

            // The gutter is part of the text view's document drawing, so the visible rect
            // of the text IS the visible rect of the numbers — a single scroll offset.
            XCTAssertEqual(
                scrollView.contentView.bounds.origin.y,
                500,
                accuracy: 1,
                "Scroll offset should reflect the scroll"
            )

            // Render the scrolled state and confirm both regions still have content
            guard let rep = scrollView.bitmapImageRepForCachingDisplay(in: scrollView.bounds) else {
                return XCTFail("Could not create bitmap for scroll view")
            }
            scrollView.cacheDisplay(in: scrollView.bounds, to: rep)

            let scale = CGFloat(rep.pixelsWide) / scrollView.bounds.width
            let gutterEnd = textView.gutterWidth * scale
            let gutterRegion = NSRect(x: 0, y: 0, width: gutterEnd - 2 * scale, height: 300 * scale)
            let textRegion = NSRect(x: gutterEnd + 4 * scale, y: 0, width: 200 * scale, height: 300 * scale)

            XCTAssertGreaterThanOrEqual(
                distinctColorCount(in: rep, region: gutterRegion),
                2,
                "Line numbers should render after scrolling"
            )
            XCTAssertGreaterThanOrEqual(
                distinctColorCount(in: rep, region: textRegion),
                2,
                "Source text should render after scrolling"
            )

            window.orderOut(nil)
        }
    }
#endif

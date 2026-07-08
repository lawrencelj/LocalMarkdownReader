// LineNumberTextView - NSTextView subclass that draws a line-number gutter inside the text view
//
// Replaces the previous `NSRulerView`-based gutter (`LineNumberRulerView`), whose
// scroll-view ruler tiling breaks when the `NSScrollView` is hosted inside SwiftUI's
// `NSHostingView` (the ruler overlays the clip view and the document stops compositing,
// so the source text disappears). Drawing the gutter inside the text view itself avoids
// scroll-view tiling entirely: the numbers and the text are rendered by the same view in
// the same coordinate space, so both are always visible and always scroll together.
//
// The gutter reserves horizontal space with a text-container exclusion path and paints
// right-aligned line numbers per logical line (wrapped continuations are not numbered).
// Supports current-line highlighting using the system accent color.

#if os(macOS)
    import AppKit

    final class LineNumberTextView: NSTextView {
        // MARK: - Configuration

        /// Whether the line-number gutter is visible. Toggling updates the exclusion path
        /// so the text reflows into (or out of) the gutter space.
        var showsLineNumbers = false {
            didSet {
                guard showsLineNumbers != oldValue else { return }
                updateGutterGeometry()
            }
        }

        /// Font used to render line numbers (monospaced, scaled by font size multiplier).
        var lineNumberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular) {
            didSet { updateGutterGeometry() }
        }

        /// Base color for line numbers (gray at 0.4 opacity).
        var lineNumberColor = NSColor.gray.withAlphaComponent(0.4) {
            didSet { needsDisplay = true }
        }

        /// Color for the current line number (system accent color, full opacity).
        var currentLineColor = NSColor.controlAccentColor {
            didSet { needsDisplay = true }
        }

        /// The 1-indexed line number to highlight as the current line. `nil` means no highlight.
        var currentLine: Int? {
            didSet {
                guard currentLine != oldValue else { return }
                setNeedsDisplay(gutterRect(in: visibleRect))
            }
        }

        /// Color for the 1pt vertical separator at the trailing edge of the gutter.
        var separatorColor = NSColor.separatorColor {
            didSet { needsDisplay = true }
        }

        /// Current gutter width. 0 when line numbers are hidden.
        private(set) var gutterWidth: CGFloat = 0

        // MARK: - Find Highlighting

        /// Background color for non-current find matches.
        var findMatchColor = NSColor.systemYellow.withAlphaComponent(0.45)
        /// Background color for the current find match.
        var findCurrentMatchColor = NSColor.systemOrange.withAlphaComponent(0.85)
        /// Called when the text view becomes first responder (drives Cmd-F focus routing).
        var onBecomeFirstResponder: (() -> Void)?

        /// Character ranges currently carrying a find highlight, so they can be cleared.
        private var findHighlightRanges: [NSRange] = []

        // MARK: - Public API

        /// Updates the font size used for line number rendering.
        /// - Parameter size: The new point size for the monospaced font.
        func updateLineNumberFontSize(_ size: CGFloat) {
            lineNumberFont = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }

        /// Updates the current line highlight.
        /// - Parameter line: The 1-indexed line number to highlight, or `nil` for none.
        func updateCurrentLine(_ line: Int?) {
            currentLine = line
        }

        /// Returns the number of lines in the text view's content.
        /// Always returns at least 1 (an empty document has one line).
        func lineCount() -> Int {
            if string.isEmpty {
                return 1
            }
            return string.components(separatedBy: "\n").count
        }

        /// Computes the minimum gutter width needed to display all line numbers.
        /// Uses `max(2, digitCount)` digits at the current font size, plus 4pt padding on each side.
        /// Never returns less than 36pt.
        var requiredGutterWidth: CGFloat {
            let digitCount = max(2, String(lineCount()).count)
            let sampleString = String(repeating: "8", count: digitCount) as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: lineNumberFont]
            let textWidth = sampleString.size(withAttributes: attributes).width
            let thickness = textWidth + 4 + 4 // 4pt padding on each side
            return max(36, ceil(thickness))
        }

        // MARK: - Find Highlighting

        /// Applies find highlights over the current text using **non-destructive**
        /// layout-manager temporary attributes (the text storage / document content is never
        /// modified), scrolls the current match into view, and reports the outcome.
        ///
        /// - Returns: `(count, regexInvalid)` — total matches, and whether a regex query failed
        ///   to compile (in which case nothing is highlighted).
        @discardableResult
        func applyFindHighlights(
            query: String,
            options: FindOptions,
            currentIndex: Int,
            active: Bool
        ) -> (count: Int, regexInvalid: Bool) {
            clearFindHighlights()

            guard active, !query.isEmpty else { return (0, false) }
            if options.useRegex, !FindMatching.isValidRegex(query, options: options) {
                return (0, true)
            }

            let ranges = FindMatching.matchRanges(in: string, query: query, options: options)
            guard let layoutManager, !ranges.isEmpty else { return (ranges.count, false) }

            findHighlightRanges = ranges
            let current = min(max(currentIndex, 0), ranges.count - 1)
            for (index, range) in ranges.enumerated() {
                let color = (index == current) ? findCurrentMatchColor : findMatchColor
                layoutManager.addTemporaryAttributes([.backgroundColor: color], forCharacterRange: range)
            }
            scrollRangeToVisible(ranges[current])
            return (ranges.count, false)
        }

        /// Removes all find highlights. Safe to call when none are present.
        func clearFindHighlights() {
            guard let layoutManager else { findHighlightRanges = []
                return
            }
            for range in findHighlightRanges {
                layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
            }
            findHighlightRanges = []
        }

        // MARK: - Find & Replace

        /// Replaces the match at `index` (in the same match set as `applyFindHighlights`)
        /// with `replacement`, inserted verbatim. The edit goes through `shouldChangeText`
        /// / `didChangeText` so it is undoable and the delegate syncs the bound SwiftUI
        /// text. The caret is left just after the inserted text.
        ///
        /// - Returns: `true` if a replacement occurred (a match existed at `index`).
        @discardableResult
        func replaceMatch(at index: Int, query: String, options: FindOptions, with replacement: String) -> Bool {
            guard !query.isEmpty else { return false }
            let ranges = FindMatching.matchRanges(in: string, query: query, options: options)
            guard index >= 0, index < ranges.count else { return false }

            let range = ranges[index]
            guard shouldChangeText(in: range, replacementString: replacement) else { return false }
            textStorage?.replaceCharacters(in: range, with: replacement)
            didChangeText()

            let caret = NSRange(location: range.location + (replacement as NSString).length, length: 0)
            setSelectedRange(caret)
            scrollRangeToVisible(caret)
            return true
        }

        /// Replaces every match with `replacement` as a single undoable edit (the whole
        /// text is swapped once), keeping the document content and the bound SwiftUI text
        /// in sync via `didChangeText`.
        ///
        /// - Returns: the number of matches replaced (`0` when there were none).
        @discardableResult
        func replaceAllMatches(query: String, options: FindOptions, with replacement: String) -> Int {
            guard !query.isEmpty else { return 0 }
            let (result, count) = FindMatching.replacingAllMatches(
                in: string,
                query: query,
                options: options,
                with: replacement
            )
            guard count > 0 else { return 0 }

            let whole = NSRange(location: 0, length: (string as NSString).length)
            guard shouldChangeText(in: whole, replacementString: result) else { return 0 }
            textStorage?.replaceCharacters(in: whole, with: result)
            didChangeText()
            return count
        }

        override func becomeFirstResponder() -> Bool {
            let didBecome = super.becomeFirstResponder()
            if didBecome {
                onBecomeFirstResponder?()
            }
            return didBecome
        }

        // MARK: - Text Change Tracking

        override func didChangeText() {
            super.didChangeText()
            guard showsLineNumbers else { return }
            if requiredGutterWidth != gutterWidth {
                updateGutterGeometry()
            } else {
                // Line numbers below an edit may shift even when the width does not change;
                // the layout manager only invalidates the text area, so redraw the gutter strip.
                setNeedsDisplay(gutterRect(in: visibleRect))
            }
        }

        // MARK: - Gutter Geometry

        /// Reserves (or releases) the gutter space via a text-container exclusion path.
        private func updateGutterGeometry() {
            gutterWidth = showsLineNumbers ? requiredGutterWidth : 0

            guard let textContainer else { return }
            if showsLineNumbers {
                // Exclusion paths are in text-container coordinates; the container origin sits
                // at `textContainerOrigin` in view coordinates, so shift by the horizontal inset.
                let exclusionWidth = max(0, gutterWidth - textContainerInset.width)
                let exclusionRect = NSRect(x: 0, y: 0, width: exclusionWidth, height: 1_000_000_000)
                textContainer.exclusionPaths = [NSBezierPath(rect: exclusionRect)]
            } else {
                textContainer.exclusionPaths = []
            }
            needsDisplay = true
        }

        /// The portion of `rect` covered by the gutter strip.
        private func gutterRect(in rect: NSRect) -> NSRect {
            NSRect(x: 0, y: rect.origin.y, width: gutterWidth, height: rect.height)
        }

        // MARK: - Drawing

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            guard showsLineNumbers else { return }
            drawGutter(in: dirtyRect)
        }

        /// Draws the separator and the line numbers for every logical line whose fragment
        /// intersects `dirtyRect`. Coordinates are document (view) coordinates, so the gutter
        /// content scrolls together with the text by construction.
        private func drawGutter(in dirtyRect: NSRect) {
            guard let layoutManager, let textContainer else { return }

            // 1pt vertical separator at the trailing edge of the gutter
            separatorColor.setFill()
            NSRect(x: gutterWidth - 1, y: dirtyRect.origin.y, width: 1, height: dirtyRect.height).fill()

            let origin = textContainerOrigin

            // Fragments intersecting the dirty area, in container coordinates
            var queryRect = dirtyRect
            queryRect.origin.x = 0
            queryRect.size.width = textContainer.size.width
            queryRect.origin.y -= origin.y
            let glyphRange = layoutManager.glyphRange(forBoundingRect: queryRect, in: textContainer)

            let content = string as NSString
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            // Count lines before the drawn range to get the starting line number
            var lineNumber = 1
            if charRange.location > 0 {
                let prefix = content.substring(with: NSRange(location: 0, length: charRange.location))
                lineNumber = prefix.components(separatedBy: "\n").count
            }

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: lineNumberFont,
                .foregroundColor: lineNumberColor,
                .paragraphStyle: paragraphStyle
            ]
            let highlightAttributes: [NSAttributedString.Key: Any] = [
                .font: lineNumberFont,
                .foregroundColor: currentLineColor,
                .paragraphStyle: paragraphStyle
            ]

            func drawNumber(_ number: Int, fragmentRect: NSRect) {
                let numberString = "\(number)" as NSString
                let attributes = (number == currentLine) ? highlightAttributes : baseAttributes
                let drawRect = NSRect(
                    x: 0,
                    y: fragmentRect.origin.y + origin.y,
                    width: gutterWidth - 4 - 1, // 4pt right padding, 1pt for separator
                    height: fragmentRect.height
                )
                numberString.draw(in: drawRect, withAttributes: attributes)
            }

            var isFirstFragment = true
            layoutManager
                .enumerateLineFragments(forGlyphRange: glyphRange) { fragmentRect, _, _, fragmentGlyphRange, _ in
                    let fragmentCharRange = layoutManager.characterRange(
                        forGlyphRange: fragmentGlyphRange,
                        actualGlyphRange: nil
                    )

                    // Number only fragments that start a new logical line (not wrapped continuations)
                    let isNewLine: Bool
                    if fragmentCharRange.location == 0 {
                        isNewLine = true
                    } else {
                        isNewLine = content.character(at: fragmentCharRange.location - 1) == 0x0A // "\n"
                    }

                    if isNewLine || isFirstFragment {
                        drawNumber(lineNumber, fragmentRect: fragmentRect)
                        lineNumber += 1
                    }
                    isFirstFragment = false
                }

            // The extra line fragment stands in for the empty last line (trailing newline
            // or empty document); number it with the final line number.
            if layoutManager.extraLineFragmentTextContainer != nil {
                let extraRect = layoutManager.extraLineFragmentRect
                if extraRect.offsetBy(dx: 0, dy: origin.y).intersects(dirtyRect) {
                    drawNumber(lineCount(), fragmentRect: extraRect)
                }
            }
        }
    }
#endif

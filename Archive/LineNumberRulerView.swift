/// LineNumberRulerView - NSRulerView subclass that draws line numbers for the source editor

import AppKit

/// A custom `NSRulerView` that displays line numbers aligned to the text view's content.
///
/// Attaches to the `NSScrollView`'s `verticalRulerView` slot and draws right-aligned
/// line numbers by iterating through the `NSLayoutManager`'s line fragment rects.
/// Supports current-line highlighting using the system accent color.
final class LineNumberRulerView: NSRulerView {

    // MARK: - Configuration

    /// Font used to render line numbers (monospaced, scaled by font size multiplier).
    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular) {
        didSet { needsDisplay = true }
    }

    /// Base color for line numbers (gray at 0.4 opacity).
    var textColor: NSColor = NSColor.gray.withAlphaComponent(0.4) {
        didSet { needsDisplay = true }
    }

    /// Color for the current line number (system accent color, full opacity).
    var currentLineColor: NSColor = NSColor.controlAccentColor {
        didSet { needsDisplay = true }
    }

    /// The 1-indexed line number to highlight as the current line. `nil` means no highlight.
    var currentLine: Int? {
        didSet { needsDisplay = true }
    }

    /// Color for the 1pt vertical separator at the trailing edge.
    var separatorColor: NSColor = NSColor.separatorColor {
        didSet { needsDisplay = true }
    }

    // MARK: - Internal References

    private weak var textView: NSTextView?

    // MARK: - Lifecycle

    /// Designated initializer.
    /// - Parameters:
    ///   - scrollView: The scroll view that hosts the text view.
    ///   - textView: The text view whose content determines line numbers.
    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = requiredThickness
        registerNotifications()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    /// Updates the font size used for line number rendering.
    /// - Parameter size: The new point size for the monospaced font.
    func updateFontSize(_ size: CGFloat) {
        font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        ruleThickness = requiredThickness
        needsDisplay = true
    }

    /// Updates the current line highlight.
    /// - Parameter line: The 1-indexed line number to highlight, or `nil` for none.
    func updateCurrentLine(_ line: Int?) {
        currentLine = line
    }

    // MARK: - Notifications

    private func registerNotifications() {
        let nc = NotificationCenter.default

        nc.addObserver(
            self,
            selector: #selector(handleTextChange(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: textView?.textStorage
        )

        if let clipView = scrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            nc.addObserver(
                self,
                selector: #selector(handleScrollChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }
    }

    @objc private func handleTextChange(_ notification: Notification) {
        ruleThickness = requiredThickness
        needsDisplay = true
    }

    @objc private func handleScrollChange(_ notification: Notification) {
        needsDisplay = true
    }

    // MARK: - Line Count

    /// Returns the number of lines in the text view's content.
    /// Always returns at least 1 (an empty document has one line).
    func lineCount() -> Int {
        guard let text = textView?.string else { return 1 }
        if text.isEmpty { return 1 }
        return text.components(separatedBy: "\n").count
    }

    // MARK: - Required Thickness

    /// Computes the minimum gutter width needed to display all line numbers.
    /// Uses `max(2, digitCount)` digits at the current font size, plus 4pt padding on each side.
    /// Never returns less than 36pt.
    override var requiredThickness: CGFloat {
        let count = lineCount()
        let digitCount = max(2, String(count).count)

        let sampleString = String(repeating: "8", count: digitCount) as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textWidth = sampleString.size(withAttributes: attributes).width

        let thickness = textWidth + 4 + 4 // 4pt padding on each side
        return max(36, ceil(thickness))
    }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        // Fill background
        NSColor.textBackgroundColor.setFill()
        rect.fill()

        // Draw the 1pt vertical separator at the trailing edge
        separatorColor.setFill()
        let separatorRect = NSRect(
            x: bounds.width - 1,
            y: rect.origin.y,
            width: 1,
            height: rect.height
        )
        separatorRect.fill()

        // Calculate visible range in the text view's coordinate system
        guard let clipView = scrollView?.contentView else { return }
        let visibleRect = clipView.bounds
        let textContainerInset = textView.textContainerInset

        // Visible glyph range
        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )

        // Determine the starting line number for the visible range
        let content = textView.string as NSString
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange,
            actualGlyphRange: nil
        )

        // Count lines before the visible range to get starting line number
        var startingLineNumber = 1
        if visibleCharRange.location > 0 {
            let prefixRange = NSRange(location: 0, length: visibleCharRange.location)
            let prefix = content.substring(with: prefixRange)
            startingLineNumber = prefix.components(separatedBy: "\n").count
        }

        // Attributes for drawing line numbers
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: currentLineColor,
            .paragraphStyle: paragraphStyle
        ]

        // Enumerate line fragment rects in the visible range
        var lineNumber = startingLineNumber
        var previousFragmentOriginY: CGFloat = -1

        layoutManager.enumerateLineFragments(
            forGlyphRange: visibleGlyphRange
        ) { [weak self] (fragmentRect, _, _, glyphRange, _) in
            guard let self = self else { return }

            // Determine if this is a new logical line or a wrapped continuation
            let charRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )

            // Check if this fragment starts a new logical line
            let isNewLine: Bool
            if charRange.location == 0 {
                isNewLine = true
            } else {
                let previousChar = content.character(at: charRange.location - 1)
                isNewLine = previousChar == 0x0A // newline character
            }

            if isNewLine || previousFragmentOriginY < 0 {
                // Draw the line number
                let lineNumberString = "\(lineNumber)" as NSString
                let attributes = (lineNumber == self.currentLine) ? highlightAttributes : baseAttributes

                // Calculate the y-position: align with the text line in the ruler's coordinate
                let yPosition = fragmentRect.origin.y + textContainerInset.height - visibleRect.origin.y

                // Draw area: right-aligned within the gutter, with 4pt right padding
                let drawRect = NSRect(
                    x: 0,
                    y: yPosition,
                    width: self.bounds.width - 4 - 1, // 4pt right padding, 1pt for separator
                    height: fragmentRect.height
                )

                lineNumberString.draw(in: drawRect, withAttributes: attributes)
                lineNumber += 1
            }

            previousFragmentOriginY = fragmentRect.origin.y
        }
    }
}

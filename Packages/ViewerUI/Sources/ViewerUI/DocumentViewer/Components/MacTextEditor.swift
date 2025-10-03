#if os(macOS)
import AppKit
import SwiftUI

/// AppKit-backed text editor that supports programmatic focus and editing.
struct MacTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var showLineNumbers: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollablePlainDocumentContentTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.usesFindPanel = true
        textView.allowsUndo = true

        // Make text view background transparent to show alternating line backgrounds
        textView.drawsBackground = false

        // Add alternating line background view behind text
        let backgroundView = AlternatingLineBackgroundView(textView: textView)
        textView.enclosingScrollView?.contentView.addSubview(backgroundView, positioned: .below, relativeTo: textView)
        backgroundView.frame = textView.bounds
        backgroundView.autoresizingMask = [.width, .height]

        // Configure text container for proper wrapping and display
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Set min/max size for proper layout
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            // Let containerSize be determined by widthTracksTextView for proper layout with line numbers
            textContainer.containerSize = NSSize(width: textContainer.lineFragmentPadding, height: CGFloat.greatestFiniteMagnitude)
        }

        // Setup line number ruler if enabled
        if showLineNumbers {
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            let rulerView = LineNumberRulerView(textView: textView)
            scrollView.verticalRulerView = rulerView
        }

        // Set the initial text
        textView.string = text

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        if isFocused && scrollView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: MacTextEditor

        init(_ parent: MacTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Line Number Ruler View

/// Custom ruler view that displays line numbers
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private var lineNumberFont: NSFont

    init(textView: NSTextView) {
        self.textView = textView
        self.lineNumberFont = .monospacedSystemFont(ofSize: 10, weight: .regular)

        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)

        self.clientView = textView
        self.ruleThickness = 40

        // Register for text change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Background
        NSColor.controlBackgroundColor.setFill()
        rect.fill()

        // Separator line
        NSColor.separatorColor.setStroke()
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: rect.maxX - 0.5, y: rect.minY))
        linePath.line(to: NSPoint(x: rect.maxX - 0.5, y: rect.maxY))
        linePath.lineWidth = 1
        linePath.stroke()

        let content = textView.string
        let visibleRect = textView.visibleRect
        let range = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        var lineNumber = 1

        // Count lines before visible range
        let charRange = layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
        let prefix = (content as NSString).substring(to: charRange.location)
        lineNumber += prefix.components(separatedBy: .newlines).count - 1

        // Draw line numbers for visible range
        layoutManager.enumerateLineFragments(forGlyphRange: range) { _, usedRect, _, glyphRange, _ in
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let line = (content as NSString).substring(with: charRange)

            if line.contains("\n") || charRange.location + charRange.length == content.count {
                // Calculate baseline-aligned Y position
                // usedRect gives us the line fragment rectangle
                let lineFragmentY = usedRect.origin.y + textView.textContainerInset.height

                // Get the font being used in the text view for baseline alignment
                let textFont = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

                // Calculate baseline offset - align line number baseline with text baseline
                // The baseline is at (ascender) distance from the top of the line
                let baselineOffset = textFont.ascender - self.lineNumberFont.ascender
                let yPosition = lineFragmentY + baselineOffset

                let lineNumberString = "\(lineNumber)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: self.lineNumberFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]

                let size = lineNumberString.size(withAttributes: attributes)
                let drawRect = NSRect(
                    x: rect.minX + 8,
                    y: yPosition,
                    width: size.width,
                    height: size.height
                )

                lineNumberString.draw(in: drawRect, withAttributes: attributes)
                lineNumber += 1
            }
        }
    }
}

// MARK: - Alternating Line Background View

/// Custom view that draws alternating line backgrounds with 5-degree shade difference
final class AlternatingLineBackgroundView: NSView {
    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(frame: textView.bounds)

        // Register for text change notifications to redraw
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Base background color
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        let content = textView.string
        let visibleRect = textView.visibleRect
        let range = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        var lineNumber = 0

        // Count lines before visible range
        let charRange = layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
        let prefix = (content as NSString).substring(to: charRange.location)
        lineNumber = prefix.components(separatedBy: .newlines).count - 1

        // Draw alternating backgrounds for visible lines
        layoutManager.enumerateLineFragments(forGlyphRange: range) { _, usedRect, _, glyphRange, _ in
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let line = (content as NSString).substring(with: charRange)

            if line.contains("\n") || charRange.location + charRange.length == content.count {
                let lineRect = NSRect(
                    x: dirtyRect.minX,
                    y: usedRect.origin.y + textView.textContainerInset.height,
                    width: dirtyRect.width,
                    height: usedRect.height
                )

                // Alternating shade with 5-degree difference (0.014 opacity)
                let opacity: CGFloat = lineNumber % 2 == 0 ? 0.03 : 0.044
                NSColor.controlAccentColor.withAlphaComponent(opacity).setFill()
                lineRect.fill()

                lineNumber += 1
            }
        }
    }
}

#endif

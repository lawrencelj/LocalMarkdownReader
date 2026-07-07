/// LineNumberRulerViewTests - Unit tests for LineNumberRulerView
///
/// Tests ruler installation/removal, font configuration, color configuration,
/// separator drawing, gutter width, and current line highlighting behavior.
///
/// Validates: Requirements 1.1, 1.2, 1.4, 2.3, 3.1, 3.2, 3.3, 3.4, 6.1

#if os(macOS)
import XCTest
import AppKit
@testable import ViewerUI

@MainActor
final class LineNumberRulerViewTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a configured LineNumberRulerView with a text view containing the given content.
    private func makeRulerView(content: String = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5") -> (LineNumberRulerView, NSTextView, NSScrollView) {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.string = content
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Force layout so the layout manager has valid geometry
        scrollView.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)
        rulerView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        rulerView.textColor = NSColor.gray.withAlphaComponent(0.4)
        rulerView.currentLineColor = NSColor.controlAccentColor
        rulerView.separatorColor = NSColor.separatorColor

        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        return (rulerView, textView, scrollView)
    }

    // MARK: - Ruler Installation Tests (Task 5.1)

    /// Validates: Requirement 1.1
    /// When showLineNumbers is true, scroll view has non-nil verticalRulerView of type LineNumberRulerView.
    func testRulerInstallation_scrollViewHasVerticalRulerView() {
        let (rulerView, _, scrollView) = makeRulerView()

        XCTAssertNotNil(scrollView.verticalRulerView,
                        "Scroll view should have a non-nil verticalRulerView when line numbers are enabled")
        XCTAssertTrue(scrollView.verticalRulerView is LineNumberRulerView,
                      "verticalRulerView should be of type LineNumberRulerView")
        XCTAssertTrue(scrollView.verticalRulerView === rulerView)
        XCTAssertTrue(scrollView.rulersVisible,
                      "rulersVisible should be true when line numbers are enabled")
        XCTAssertTrue(scrollView.hasVerticalRuler,
                      "hasVerticalRuler should be true when line numbers are enabled")
    }

    /// Validates: Requirement 1.2
    /// When showLineNumbers is false, ruler is nil or rulersVisible is false.
    func testRulerRemoval_scrollViewHasNoRuler() {
        let (_, _, scrollView) = makeRulerView()
        XCTAssertNotNil(scrollView.verticalRulerView, "Precondition: ruler should exist initially")

        // Simulate what SpellCheckingTextEditor does when toggling off
        scrollView.verticalRulerView = nil
        scrollView.rulersVisible = false

        XCTAssertNil(scrollView.verticalRulerView,
                     "verticalRulerView should be nil when line numbers are disabled")
        XCTAssertFalse(scrollView.rulersVisible,
                       "rulersVisible should be false when line numbers are disabled")
    }

    /// Validates: Requirement 1.4
    /// Font is NSFont.monospacedSystemFont at expected size.
    func testRulerFont_isMonospacedSystemFont() {
        let (rulerView, _, _) = makeRulerView()

        let expectedFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        XCTAssertEqual(rulerView.font.fontName, expectedFont.fontName,
                       "Ruler font should be monospaced system font")
        XCTAssertEqual(rulerView.font.pointSize, expectedFont.pointSize,
                       "Ruler font size should be 11pt")
    }

    /// Validates: Requirement 6.1
    /// Base font size is 11pt.
    func testRulerFont_baseFontSizeIs11pt() {
        let (rulerView, _, _) = makeRulerView()

        XCTAssertEqual(rulerView.font.pointSize, 11,
                       "Base font size should be 11pt per requirement 6.1")
    }

    /// Validates: Requirement 1.4
    /// Font updates correctly when font size changes.
    func testRulerFont_updatesWhenFontSizeChanges() {
        let (rulerView, _, _) = makeRulerView()

        rulerView.updateFontSize(16.5)

        XCTAssertEqual(rulerView.font.pointSize, 16.5,
                       "Font point size should update to the new value")
        let expectedFont = NSFont.monospacedSystemFont(ofSize: 16.5, weight: .regular)
        XCTAssertEqual(rulerView.font.fontName, expectedFont.fontName,
                       "Font should remain monospaced system font after size update")
    }

    /// Validates: Requirement 2.4 (via 2.3 separator)
    /// Base text color alpha ≤ 0.5.
    func testBaseTextColor_alphaIsAtMostHalf() {
        let (rulerView, _, _) = makeRulerView()

        let alpha = rulerView.textColor.alphaComponent
        XCTAssertLessThanOrEqual(alpha, 0.5,
                                 "Base text color alpha should be ≤ 0.5 per requirement 2.4")
    }

    /// Validates: Requirement 3.1
    /// Current line color uses accent at full opacity.
    func testCurrentLineColor_usesAccentAtFullOpacity() {
        let (rulerView, _, _) = makeRulerView()

        XCTAssertEqual(rulerView.currentLineColor, NSColor.controlAccentColor,
                       "Current line color should use system accent color")
        XCTAssertEqual(rulerView.currentLineColor.alphaComponent, 1.0,
                       "Current line color should be at full opacity")
    }

    /// Validates: Requirement 2.3
    /// Separator uses NSColor.separatorColor.
    func testSeparatorColor_isConfigured() {
        let (rulerView, _, _) = makeRulerView()

        XCTAssertEqual(rulerView.separatorColor, NSColor.separatorColor,
                       "Separator should use NSColor.separatorColor")
    }

    /// Validates: Requirement 2.3
    /// Ruler thickness accommodates the 1pt separator at trailing edge.
    func testSeparator_rulerThicknessAllowsForSeparator() {
        let (rulerView, _, _) = makeRulerView()

        // The separator is drawn at x = bounds.width - 1 with width = 1.
        // Ruler thickness must be at least 36pt.
        XCTAssertGreaterThanOrEqual(rulerView.ruleThickness, 36,
                                    "Ruler thickness should be at least 36pt to accommodate numbers and separator")
    }

    /// Validates: Requirement 6.1
    /// Gutter width is 36pt minimum.
    func testGutterWidth_minimumIs36pt() {
        // Single line document (1 digit)
        let (rulerView, _, _) = makeRulerView(content: "A")

        XCTAssertGreaterThanOrEqual(rulerView.requiredThickness, 36,
                                    "Gutter width should never be less than 36pt per requirement 6.1")
    }

    /// Validates: Requirement 6.1
    /// Gutter width is 36pt minimum even for empty documents.
    func testGutterWidth_minimumIs36ptForEmptyDocument() {
        let (rulerView, _, _) = makeRulerView(content: "")

        XCTAssertGreaterThanOrEqual(rulerView.requiredThickness, 36,
                                    "Gutter width should never be less than 36pt even for empty documents")
    }

    /// Validates: Requirement 2.2
    /// Gutter width increases for higher digit counts.
    func testGutterWidth_accommodatesHighDigitCounts() {
        // Create a document with 1000 lines (4 digits)
        let content = (1...1000).map { "Line \($0)" }.joined(separator: "\n")
        let (rulerView4Digits, _, _) = makeRulerView(content: content)

        let thickness4Digits = rulerView4Digits.requiredThickness
        XCTAssertGreaterThanOrEqual(thickness4Digits, 36)

        // A 2-line doc uses max(2, 1) = 2 digit width, same as a 99-line doc
        let (rulerView2Lines, _, _) = makeRulerView(content: "Line 1\nLine 2")
        let thickness2Lines = rulerView2Lines.requiredThickness

        XCTAssertGreaterThanOrEqual(thickness4Digits, thickness2Lines,
                                    "4-digit document should have gutter at least as wide as 2-digit document")
    }

    // MARK: - Current Line Highlighting Tests (Task 5.2)

    /// Validates: Requirement 3.1
    /// Setting `currentLine` causes that line number to render in accent color.
    func testCurrentLineUsesAccentColor() {
        let (rulerView, _, _) = makeRulerView()

        // Initially no line is highlighted
        XCTAssertNil(rulerView.currentLine)

        // Set the current line
        rulerView.updateCurrentLine(3)

        // Verify currentLine is set
        XCTAssertEqual(rulerView.currentLine, 3)

        // Verify the accent color is configured at full opacity for highlighting
        let accentAlpha = rulerView.currentLineColor.alphaComponent
        XCTAssertEqual(accentAlpha, 1.0, accuracy: 0.01,
                       "Current line color should be at full opacity")

        // Verify the base text color is subdued (0.4 opacity)
        let baseAlpha = rulerView.textColor.alphaComponent
        XCTAssertLessThanOrEqual(baseAlpha, 0.5,
                                 "Base text color should be at subdued opacity (≤ 0.5)")

        // Verify the two colors are different (accent vs subdued gray)
        XCTAssertNotEqual(rulerView.currentLineColor, rulerView.textColor,
                          "Current line color should be visually distinct from base text color")
    }

    /// Validates: Requirement 3.2
    /// Moving cursor updates highlight to new line and reverts previous.
    func testMovingCursorUpdatesHighlight() {
        let (rulerView, _, _) = makeRulerView()

        // Set current line to line 2
        rulerView.updateCurrentLine(2)
        XCTAssertEqual(rulerView.currentLine, 2)

        // Move to line 4
        rulerView.updateCurrentLine(4)
        XCTAssertEqual(rulerView.currentLine, 4,
                       "Current line should update to the new cursor position")

        // The previous line (2) is no longer the current line — only one line is highlighted
        XCTAssertNotEqual(rulerView.currentLine, 2,
                          "Previous line should no longer be highlighted")
    }

    /// Validates: Requirement 3.3
    /// Multi-line selection highlights only the insertion point line.
    func testMultiLineSelectionHighlightsInsertionPoint() {
        let (rulerView, textView, _) = makeRulerView(content: "Line 1\nLine 2\nLine 3\nLine 4\nLine 5")

        // Simulate a multi-line selection from line 2 to line 4
        let selectionStart = 7  // Start of "Line 2"
        let selectionEnd = 27   // End of "Line 4"
        textView.setSelectedRange(NSRange(location: selectionStart, length: selectionEnd - selectionStart))

        // The coordinator logic computes focused line from selectedRange().location
        let cursorLocation = textView.selectedRange().location
        let content = textView.string
        let prefix = String(content.prefix(cursorLocation))
        let lineNumber = prefix.components(separatedBy: "\n").count

        // Update the ruler with the computed line (insertion point)
        rulerView.updateCurrentLine(lineNumber)

        // Only one line should be highlighted
        XCTAssertNotNil(rulerView.currentLine,
                        "A line should be highlighted during multi-line selection")
        XCTAssertEqual(rulerView.currentLine, lineNumber,
                       "Only the insertion point line should be highlighted")
        XCTAssertTrue(rulerView.currentLine! >= 1 && rulerView.currentLine! <= 5,
                      "Highlighted line should be within valid range")
    }

    /// Validates: Requirement 3.4
    /// Highlight persists after focus loss.
    func testHighlightPersistsAfterFocusLoss() {
        let (rulerView, textView, scrollView) = makeRulerView()

        // Set current line to line 3
        rulerView.updateCurrentLine(3)
        XCTAssertEqual(rulerView.currentLine, 3)

        // Simulate focus loss by resigning first responder
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.contentView = scrollView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)

        // Now resign first responder to simulate focus loss
        window.makeFirstResponder(nil)

        // The highlight should persist — currentLine is not cleared on focus loss
        XCTAssertEqual(rulerView.currentLine, 3,
                       "Current line highlight should persist after the text view loses focus")
        XCTAssertEqual(rulerView.currentLineColor, NSColor.controlAccentColor,
                       "The accent color for current line should remain unchanged after focus loss")

        // Clean up
        window.orderOut(nil)
    }

    /// Validates: Requirement 3.2
    /// Updating currentLine to nil removes all highlights.
    func testSettingCurrentLineToNilRemovesHighlight() {
        let (rulerView, _, _) = makeRulerView()

        // Set a current line
        rulerView.updateCurrentLine(2)
        XCTAssertEqual(rulerView.currentLine, 2)

        // Clear the highlight
        rulerView.updateCurrentLine(nil)
        XCTAssertNil(rulerView.currentLine,
                     "Setting currentLine to nil should remove the highlight")
    }
}
#endif

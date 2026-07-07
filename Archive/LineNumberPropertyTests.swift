/// LineNumberPropertyTests - Property-based tests for LineNumberRulerView
///
/// Validates correctness properties of the line number gutter using randomized inputs.

#if os(macOS)
import XCTest
import AppKit
@testable import ViewerUI

@MainActor
final class LineNumberPropertyTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a LineNumberRulerView with a text view containing the given string.
    private func makeRulerView(text: String, fontSize: CGFloat = 11) -> LineNumberRulerView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = text
        scrollView.documentView = textView
        let ruler = LineNumberRulerView(scrollView: scrollView, textView: textView)
        ruler.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        return ruler
    }

    /// Generates a string with exactly `lineCount` lines (lineCount - 1 newlines).
    private func textWithLineCount(_ lineCount: Int) -> String {
        guard lineCount > 1 else { return "x" }
        // N lines = N-1 newlines separating single-character lines
        return (1...lineCount).map { _ in "x" }.joined(separator: "\n")
    }

    // MARK: - Property 2: Gutter width accommodates digit count with minimum of two digits

    /// **Validates: Requirements 2.2**
    ///
    /// Property 2: Gutter width accommodates digit count with minimum of two digits
    ///
    /// For any line count N in [1, 999999], the computed gutter width (requiredThickness) SHALL:
    /// - Be sufficient to display max(2, String(N).count) digits at the configured font size plus padding
    /// - Never be less than the width required for 2-digit numbers (minimum 36pt)
    func testGutterWidthAccommodatesDigitCount() {
        let iterations = 150

        for i in 0..<iterations {
            // Generate a random line count in [1, 999999]
            let lineCount = Int.random(in: 1...999999)

            // Create text with the target number of lines
            // For performance with large line counts, we compute expected thickness
            // directly using the ruler's font metrics rather than creating huge strings.
            let fontSize: CGFloat = 11
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

            // Expected digit count per the spec
            let expectedDigitCount = max(2, String(lineCount).count)

            // Compute the minimum text width needed for expectedDigitCount digits
            let sampleString = String(repeating: "8", count: expectedDigitCount) as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let expectedTextWidth = sampleString.size(withAttributes: attributes).width
            let expectedMinThickness = max(36, ceil(expectedTextWidth + 4 + 4))

            // For small line counts, we can actually create the ruler and verify directly
            if lineCount <= 10000 {
                let text = textWithLineCount(lineCount)
                let ruler = makeRulerView(text: text, fontSize: fontSize)
                let actualThickness = ruler.requiredThickness

                // The ruler's thickness must accommodate the digit count
                XCTAssertGreaterThanOrEqual(
                    actualThickness,
                    expectedMinThickness,
                    "Iteration \(i): For lineCount=\(lineCount) (digits=\(expectedDigitCount)), " +
                    "requiredThickness \(actualThickness) should be >= \(expectedMinThickness)"
                )

                // The ruler's thickness must never be less than 36pt (2-digit minimum)
                XCTAssertGreaterThanOrEqual(
                    actualThickness,
                    36,
                    "Iteration \(i): For lineCount=\(lineCount), " +
                    "requiredThickness \(actualThickness) should never be less than 36pt"
                )
            } else {
                // For large line counts, verify the formula directly against the ruler
                // by creating a smaller text and manually checking the computation logic.
                // We create a text with a line count that has the same digit magnitude.
                let representativeCount = Int(pow(10.0, Double(expectedDigitCount - 1)))
                let text = textWithLineCount(representativeCount)
                let ruler = makeRulerView(text: text, fontSize: fontSize)
                let actualThickness = ruler.requiredThickness

                // The actual thickness for a representative count of the same digit magnitude
                // should equal what we'd expect for the tested line count
                XCTAssertGreaterThanOrEqual(
                    actualThickness,
                    expectedMinThickness,
                    "Iteration \(i): For lineCount=\(lineCount) (digits=\(expectedDigitCount)), " +
                    "representative ruler thickness \(actualThickness) should be >= \(expectedMinThickness)"
                )

                // Never less than minimum 36pt
                XCTAssertGreaterThanOrEqual(
                    actualThickness,
                    36,
                    "Iteration \(i): For lineCount=\(lineCount), " +
                    "requiredThickness should never be less than 36pt"
                )
            }
        }
    }

    /// Validates the minimum 2-digit width boundary specifically.
    /// Tests that even for single-line documents, the gutter is at least 36pt wide.
    func testGutterWidthNeverBelowTwoDigitMinimum() {
        let iterations = 100

        for i in 0..<iterations {
            // Test single-digit line counts specifically (1-9)
            let lineCount = Int.random(in: 1...9)
            let text = textWithLineCount(lineCount)
            let ruler = makeRulerView(text: text)
            let thickness = ruler.requiredThickness

            XCTAssertGreaterThanOrEqual(
                thickness,
                36,
                "Iteration \(i): For lineCount=\(lineCount), " +
                "requiredThickness \(thickness) should be >= 36pt (2-digit minimum)"
            )

            // Verify it can accommodate at least 2 digits
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let twoDigitString = "88" as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let twoDigitWidth = twoDigitString.size(withAttributes: attributes).width
            let minTwoDigitThickness = ceil(twoDigitWidth + 4 + 4)

            XCTAssertGreaterThanOrEqual(
                thickness,
                minTwoDigitThickness,
                "Iteration \(i): For lineCount=\(lineCount), " +
                "requiredThickness \(thickness) should accommodate 2 digits (\(minTwoDigitThickness)pt)"
            )
        }
    }
    // MARK: - Helpers for Property 3 and 4

    /// Generates a random text string with interspersed newlines for toggle testing.
    private func generateRandomText(maxLength: Int = 300) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \t!@#"
        let length = Int.random(in: 0...maxLength)
        var result = ""
        for _ in 0..<length {
            if Int.random(in: 0...9) < 2 {
                result.append("\n")
            } else {
                result.append(characters.randomElement()!)
            }
        }
        return result
    }

    // MARK: - Property 3: Toggle preserves document state

    /// **Validates: Requirements 5.3**
    ///
    /// Property 3: Toggle preserves document state
    ///
    /// For any text content and any cursor position within that content, toggling
    /// `showLineNumbers` from any state to the opposite state SHALL result in the
    /// text content being identical before and after the toggle, and the cursor
    /// position (character index) being unchanged.
    func testTogglePreservesDocumentState() {
        for _ in 0..<100 {
            // Generate random text content
            let randomText = generateRandomText(maxLength: 300)

            // Create a scroll view + text view setup
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            textView.isEditable = true
            textView.isSelectable = true
            textView.isRichText = false
            textView.string = randomText
            scrollView.documentView = textView

            // Set a random valid cursor position
            let textLength = (randomText as NSString).length
            let cursorPosition: Int
            if textLength > 0 {
                cursorPosition = Int.random(in: 0...textLength)
            } else {
                cursorPosition = 0
            }
            textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))

            // Record state before toggle
            let textBefore = textView.string
            let cursorBefore = textView.selectedRange()

            // Toggle ON: install the ruler
            let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)
            rulerView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            rulerView.textColor = NSColor.gray.withAlphaComponent(0.4)
            rulerView.currentLineColor = NSColor.controlAccentColor
            rulerView.separatorColor = NSColor.separatorColor
            scrollView.verticalRulerView = rulerView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true

            // Verify text and cursor after toggle ON
            let textAfterOn = textView.string
            let cursorAfterOn = textView.selectedRange()

            XCTAssertEqual(
                textBefore, textAfterOn,
                "Text content changed after toggling line numbers ON"
            )
            XCTAssertEqual(
                cursorBefore, cursorAfterOn,
                "Cursor position changed after toggling line numbers ON: " +
                "was \(cursorBefore), now \(cursorAfterOn)"
            )

            // Toggle OFF: remove the ruler
            scrollView.verticalRulerView = nil
            scrollView.rulersVisible = false

            // Verify text and cursor after toggle OFF
            let textAfterOff = textView.string
            let cursorAfterOff = textView.selectedRange()

            XCTAssertEqual(
                textBefore, textAfterOff,
                "Text content changed after toggling line numbers OFF"
            )
            XCTAssertEqual(
                cursorBefore, cursorAfterOff,
                "Cursor position changed after toggling line numbers OFF: " +
                "was \(cursorBefore), now \(cursorAfterOff)"
            )
        }
    }

    /// **Validates: Requirements 5.3**
    ///
    /// Edge case: Toggle preserves state with empty document.
    func testTogglePreservesStateWithEmptyDocument() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.string = ""
        scrollView.documentView = textView
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        let textBefore = textView.string
        let cursorBefore = textView.selectedRange()

        // Toggle ON
        let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        XCTAssertEqual(textView.string, textBefore, "Empty document text changed on toggle ON")
        XCTAssertEqual(textView.selectedRange(), cursorBefore, "Empty document cursor changed on toggle ON")

        // Toggle OFF
        scrollView.verticalRulerView = nil
        scrollView.rulersVisible = false

        XCTAssertEqual(textView.string, textBefore, "Empty document text changed on toggle OFF")
        XCTAssertEqual(textView.selectedRange(), cursorBefore, "Empty document cursor changed on toggle OFF")
    }

    /// **Validates: Requirements 5.3**
    ///
    /// Edge case: Multiple rapid toggles preserve state.
    func testMultipleRapidTogglesPreserveState() {
        for _ in 0..<20 {
            let randomText = generateRandomText(maxLength: 200)
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            textView.isEditable = true
            textView.isSelectable = true
            textView.isRichText = false
            textView.string = randomText
            scrollView.documentView = textView

            let textLength = (randomText as NSString).length
            let cursorPosition = textLength > 0 ? Int.random(in: 0...textLength) : 0
            textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))

            let textBefore = textView.string
            let cursorBefore = textView.selectedRange()

            // Rapidly toggle 10 times
            for _ in 0..<10 {
                let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)
                scrollView.verticalRulerView = rulerView
                scrollView.hasVerticalRuler = true
                scrollView.rulersVisible = true

                scrollView.verticalRulerView = nil
                scrollView.rulersVisible = false
            }

            XCTAssertEqual(
                textView.string, textBefore,
                "Text content changed after multiple rapid toggles"
            )
            XCTAssertEqual(
                textView.selectedRange(), cursorBefore,
                "Cursor position changed after multiple rapid toggles"
            )
        }
    }

    // MARK: - Property 4: Font size scales linearly with multiplier

    /// **Validates: Requirements 6.2**
    ///
    /// Property 4: Font size scales linearly with multiplier
    ///
    /// For any font size multiplier value M in the range [0.5, 3.0], the displayed
    /// line number font size SHALL equal exactly 11.0 * M points.
    func testFontSizeScalesLinearlyWithMultiplier() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.string = "Test content\nLine 2\nLine 3"
        scrollView.documentView = textView

        let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)

        for _ in 0..<100 {
            // Generate a random multiplier in [0.5, 3.0]
            let multiplier = Double.random(in: 0.5...3.0)
            let expectedFontSize = 11.0 * multiplier

            // Update the font size using the ruler's API
            rulerView.updateFontSize(CGFloat(expectedFontSize))

            // Verify the font's point size matches the expected value
            let actualFontSize = Double(rulerView.font.pointSize)
            let tolerance = 0.001

            XCTAssertEqual(
                actualFontSize,
                expectedFontSize,
                accuracy: tolerance,
                "Font size mismatch for multiplier \(multiplier): " +
                "expected \(expectedFontSize), got \(actualFontSize)"
            )
        }
    }

    /// **Validates: Requirements 6.2**
    ///
    /// Edge case: Font size at boundary multiplier values.
    func testFontSizeAtBoundaryMultipliers() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.string = "Test"
        scrollView.documentView = textView

        let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)
        let tolerance = 0.001

        // Minimum multiplier: 0.5
        let minSize = 11.0 * 0.5
        rulerView.updateFontSize(CGFloat(minSize))
        XCTAssertEqual(
            Double(rulerView.font.pointSize), minSize, accuracy: tolerance,
            "Font size at minimum multiplier 0.5: expected \(minSize), got \(rulerView.font.pointSize)"
        )

        // Maximum multiplier: 3.0
        let maxSize = 11.0 * 3.0
        rulerView.updateFontSize(CGFloat(maxSize))
        XCTAssertEqual(
            Double(rulerView.font.pointSize), maxSize, accuracy: tolerance,
            "Font size at maximum multiplier 3.0: expected \(maxSize), got \(rulerView.font.pointSize)"
        )

        // Default multiplier: 1.0
        let defaultSize = 11.0 * 1.0
        rulerView.updateFontSize(CGFloat(defaultSize))
        XCTAssertEqual(
            Double(rulerView.font.pointSize), defaultSize, accuracy: tolerance,
            "Font size at default multiplier 1.0: expected \(defaultSize), got \(rulerView.font.pointSize)"
        )
    }

    /// **Validates: Requirements 6.2**
    ///
    /// Property: Font size updates are idempotent - setting the same size twice
    /// produces the same result.
    func testFontSizeUpdateIsIdempotent() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        textView.string = "Test content"
        scrollView.documentView = textView

        let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)
        let tolerance = 0.001

        for _ in 0..<50 {
            let multiplier = Double.random(in: 0.5...3.0)
            let fontSize = 11.0 * multiplier

            // Set once
            rulerView.updateFontSize(CGFloat(fontSize))
            let firstResult = rulerView.font.pointSize

            // Set again with same value
            rulerView.updateFontSize(CGFloat(fontSize))
            let secondResult = rulerView.font.pointSize

            XCTAssertEqual(
                Double(firstResult), Double(secondResult), accuracy: tolerance,
                "Font size not idempotent for multiplier \(multiplier): " +
                "first=\(firstResult), second=\(secondResult)"
            )
        }
    }
}
#endif

// LineNumberPropertyTests - Property-based tests for LineNumberTextView
//
// Validates correctness properties of the line number gutter using randomized inputs.
// (Previous LineNumberRulerView-based version archived in Archive/.)

#if os(macOS)
    import AppKit
    @testable import ViewerUI
    import XCTest

    @MainActor
    final class LineNumberPropertyTests: XCTestCase {
        // MARK: - Helpers

        /// Creates a LineNumberTextView containing the given string with the gutter enabled.
        ///
        /// - Input: `text` — document content (String, any length),
        ///          `fontSize` — line number font point size (CGFloat, default 11).
        /// - Output: a laid-out LineNumberTextView inside a 400x300 scroll view.
        private func makeTextView(text: String, fontSize: CGFloat = 11) -> LineNumberTextView {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            let textView = LineNumberTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            scrollView.documentView = textView
            textView.string = text
            textView.lineNumberFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            textView.showsLineNumbers = true
            return textView
        }

        /// Generates a string with exactly `lineCount` lines (lineCount - 1 newlines).
        private func textWithLineCount(_ lineCount: Int) -> String {
            guard lineCount > 1 else { return "x" }
            // N lines = N-1 newlines separating single-character lines
            return (1 ... lineCount).map { _ in "x" }.joined(separator: "\n")
        }

        // MARK: - Property 2: Gutter width accommodates digit count with minimum of two digits

        /// **Validates: Requirements 2.2**
        ///
        /// Property 2: Gutter width accommodates digit count with minimum of two digits
        ///
        /// Function under test: `requiredGutterWidth`.
        /// Input: random line counts N in [1, 999999] (150 iterations).
        /// Output: gutter width sufficient for max(2, String(N).count) digits at the
        /// configured font size plus padding, and never below the 36pt two-digit minimum.
        func testGutterWidthAccommodatesDigitCount() {
            let iterations = 150

            for i in 0 ..< iterations {
                // Generate a random line count in [1, 999999]
                let lineCount = Int.random(in: 1 ... 999_999)

                // For performance with large line counts, we compute expected thickness
                // directly using the font metrics rather than creating huge strings.
                let fontSize: CGFloat = 11
                let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

                // Expected digit count per the spec
                let expectedDigitCount = max(2, String(lineCount).count)

                // Compute the minimum text width needed for expectedDigitCount digits
                let sampleString = String(repeating: "8", count: expectedDigitCount) as NSString
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                let expectedTextWidth = sampleString.size(withAttributes: attributes).width
                let expectedMinThickness = max(36, ceil(expectedTextWidth + 4 + 4))

                // For small line counts, we can actually create the view and verify directly
                if lineCount <= 10000 {
                    let text = textWithLineCount(lineCount)
                    let textView = makeTextView(text: text, fontSize: fontSize)
                    let actualThickness = textView.requiredGutterWidth

                    // The gutter width must accommodate the digit count
                    XCTAssertGreaterThanOrEqual(
                        actualThickness,
                        expectedMinThickness,
                        "Iteration \(i): For lineCount=\(lineCount) (digits=\(expectedDigitCount)), " +
                            "requiredGutterWidth \(actualThickness) should be >= \(expectedMinThickness)"
                    )

                    // The gutter width must never be less than 36pt (2-digit minimum)
                    XCTAssertGreaterThanOrEqual(
                        actualThickness,
                        36,
                        "Iteration \(i): For lineCount=\(lineCount), " +
                            "requiredGutterWidth \(actualThickness) should never be less than 36pt"
                    )
                } else {
                    // For large line counts, verify the formula using a representative text
                    // with the same digit magnitude.
                    let representativeCount = Int(pow(10.0, Double(expectedDigitCount - 1)))
                    let text = textWithLineCount(representativeCount)
                    let textView = makeTextView(text: text, fontSize: fontSize)
                    let actualThickness = textView.requiredGutterWidth

                    XCTAssertGreaterThanOrEqual(
                        actualThickness,
                        expectedMinThickness,
                        "Iteration \(i): For lineCount=\(lineCount) (digits=\(expectedDigitCount)), " +
                            "representative gutter width \(actualThickness) should be >= \(expectedMinThickness)"
                    )

                    XCTAssertGreaterThanOrEqual(
                        actualThickness,
                        36,
                        "Iteration \(i): For lineCount=\(lineCount), " +
                            "requiredGutterWidth should never be less than 36pt"
                    )
                }
            }
        }

        /// Validates the minimum 2-digit width boundary specifically.
        ///
        /// Function under test: `requiredGutterWidth`.
        /// Input: random single-digit line counts in [1, 9] (100 iterations).
        /// Output: gutter width >= 36pt and wide enough for two 11pt digits plus padding.
        func testGutterWidthNeverBelowTwoDigitMinimum() {
            let iterations = 100

            for i in 0 ..< iterations {
                // Test single-digit line counts specifically (1-9)
                let lineCount = Int.random(in: 1 ... 9)
                let text = textWithLineCount(lineCount)
                let textView = makeTextView(text: text)
                let thickness = textView.requiredGutterWidth

                XCTAssertGreaterThanOrEqual(
                    thickness,
                    36,
                    "Iteration \(i): For lineCount=\(lineCount), " +
                        "requiredGutterWidth \(thickness) should be >= 36pt (2-digit minimum)"
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
                        "requiredGutterWidth \(thickness) should accommodate 2 digits (\(minTwoDigitThickness)pt)"
                )
            }
        }

        // MARK: - Helpers for Property 3 and 4

        /// Generates a random text string with interspersed newlines for toggle testing.
        private func generateRandomText(maxLength: Int = 300) -> String {
            let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \t!@#"
            let length = Int.random(in: 0 ... maxLength)
            var result = ""
            for _ in 0 ..< length {
                if Int.random(in: 0 ... 9) < 2 {
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
        /// Function under test: `showsLineNumbers` toggling.
        /// Input: 100 random text contents (0-300 chars) with random cursor positions.
        /// Output: text content and cursor position (character index) identical before
        /// and after toggling the gutter on and off.
        func testTogglePreservesDocumentState() {
            for _ in 0 ..< 100 {
                // Generate random text content
                let randomText = generateRandomText(maxLength: 300)

                let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
                let textView = LineNumberTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
                textView.isEditable = true
                textView.isSelectable = true
                textView.isRichText = false
                textView.string = randomText
                scrollView.documentView = textView

                // Set a random valid cursor position
                let textLength = (randomText as NSString).length
                let cursorPosition: Int
                if textLength > 0 {
                    cursorPosition = Int.random(in: 0 ... textLength)
                } else {
                    cursorPosition = 0
                }
                textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))

                // Record state before toggle
                let textBefore = textView.string
                let cursorBefore = textView.selectedRange()

                // Toggle ON
                textView.showsLineNumbers = true

                // Verify text and cursor after toggle ON
                XCTAssertEqual(
                    textBefore, textView.string,
                    "Text content changed after toggling line numbers ON"
                )
                XCTAssertEqual(
                    cursorBefore, textView.selectedRange(),
                    "Cursor position changed after toggling line numbers ON: " +
                        "was \(cursorBefore), now \(textView.selectedRange())"
                )

                // Toggle OFF
                textView.showsLineNumbers = false

                // Verify text and cursor after toggle OFF
                XCTAssertEqual(
                    textBefore, textView.string,
                    "Text content changed after toggling line numbers OFF"
                )
                XCTAssertEqual(
                    cursorBefore, textView.selectedRange(),
                    "Cursor position changed after toggling line numbers OFF: " +
                        "was \(cursorBefore), now \(textView.selectedRange())"
                )
            }
        }

        /// **Validates: Requirements 5.3**
        ///
        /// Edge case: Toggle preserves state with empty document.
        /// Input: empty document, cursor at 0. Output: text and cursor unchanged by toggling.
        func testTogglePreservesStateWithEmptyDocument() {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            let textView = LineNumberTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            textView.isEditable = true
            textView.isSelectable = true
            textView.isRichText = false
            textView.string = ""
            scrollView.documentView = textView
            textView.setSelectedRange(NSRange(location: 0, length: 0))

            let textBefore = textView.string
            let cursorBefore = textView.selectedRange()

            // Toggle ON
            textView.showsLineNumbers = true

            XCTAssertEqual(textView.string, textBefore, "Empty document text changed on toggle ON")
            XCTAssertEqual(textView.selectedRange(), cursorBefore, "Empty document cursor changed on toggle ON")

            // Toggle OFF
            textView.showsLineNumbers = false

            XCTAssertEqual(textView.string, textBefore, "Empty document text changed on toggle OFF")
            XCTAssertEqual(textView.selectedRange(), cursorBefore, "Empty document cursor changed on toggle OFF")
        }

        /// **Validates: Requirements 5.3**
        ///
        /// Edge case: Multiple rapid toggles preserve state.
        /// Input: 20 random text contents, each toggled on/off 10 times.
        /// Output: text and cursor unchanged after all toggles.
        func testMultipleRapidTogglesPreserveState() {
            for _ in 0 ..< 20 {
                let randomText = generateRandomText(maxLength: 200)
                let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
                let textView = LineNumberTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
                textView.isEditable = true
                textView.isSelectable = true
                textView.isRichText = false
                textView.string = randomText
                scrollView.documentView = textView

                let textLength = (randomText as NSString).length
                let cursorPosition = textLength > 0 ? Int.random(in: 0 ... textLength) : 0
                textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))

                let textBefore = textView.string
                let cursorBefore = textView.selectedRange()

                // Rapidly toggle 10 times
                for _ in 0 ..< 10 {
                    textView.showsLineNumbers = true
                    textView.showsLineNumbers = false
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
        /// Function under test: `updateLineNumberFontSize(_:)`.
        /// Input: 100 random multipliers M in [0.5, 3.0] applied as 11.0 * M points.
        /// Output: `lineNumberFont.pointSize` equals exactly 11.0 * M (±0.001).
        func testFontSizeScalesLinearlyWithMultiplier() {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            let textView = LineNumberTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            textView.string = "Test content\nLine 2\nLine 3"
            scrollView.documentView = textView

            for _ in 0 ..< 100 {
                // Generate a random multiplier in [0.5, 3.0]
                let multiplier = Double.random(in: 0.5 ... 3.0)
                let expectedFontSize = 11.0 * multiplier

                // Update the font size using the view's API
                textView.updateLineNumberFontSize(CGFloat(expectedFontSize))

                // Verify the font's point size matches the expected value
                let actualFontSize = Double(textView.lineNumberFont.pointSize)
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
        /// Edge case: Font size at boundary multiplier values (0.5, 1.0, 3.0).
        func testFontSizeAtBoundaryMultipliers() {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            let textView = LineNumberTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            textView.string = "Test"
            scrollView.documentView = textView

            let tolerance = 0.001

            // Minimum multiplier: 0.5
            let minSize = 11.0 * 0.5
            textView.updateLineNumberFontSize(CGFloat(minSize))
            XCTAssertEqual(
                Double(textView.lineNumberFont.pointSize), minSize, accuracy: tolerance,
                "Font size at minimum multiplier 0.5: expected \(minSize), got \(textView.lineNumberFont.pointSize)"
            )

            // Maximum multiplier: 3.0
            let maxSize = 11.0 * 3.0
            textView.updateLineNumberFontSize(CGFloat(maxSize))
            XCTAssertEqual(
                Double(textView.lineNumberFont.pointSize), maxSize, accuracy: tolerance,
                "Font size at maximum multiplier 3.0: expected \(maxSize), got \(textView.lineNumberFont.pointSize)"
            )

            // Default multiplier: 1.0
            let defaultSize = 11.0 * 1.0
            textView.updateLineNumberFontSize(CGFloat(defaultSize))
            XCTAssertEqual(
                Double(textView.lineNumberFont.pointSize), defaultSize, accuracy: tolerance,
                "Font size at default multiplier 1.0: expected \(defaultSize), got \(textView.lineNumberFont.pointSize)"
            )
        }

        /// **Validates: Requirements 6.2**
        ///
        /// Property: Font size updates are idempotent - setting the same size twice
        /// produces the same result.
        func testFontSizeUpdateIsIdempotent() {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            let textView = LineNumberTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
            textView.string = "Test content"
            scrollView.documentView = textView

            let tolerance = 0.001

            for _ in 0 ..< 50 {
                let multiplier = Double.random(in: 0.5 ... 3.0)
                let fontSize = 11.0 * multiplier

                // Set once
                textView.updateLineNumberFontSize(CGFloat(fontSize))
                let firstResult = textView.lineNumberFont.pointSize

                // Set again with same value
                textView.updateLineNumberFontSize(CGFloat(fontSize))
                let secondResult = textView.lineNumberFont.pointSize

                XCTAssertEqual(
                    Double(firstResult), Double(secondResult), accuracy: tolerance,
                    "Font size not idempotent for multiplier \(multiplier): " +
                        "first=\(firstResult), second=\(secondResult)"
                )
            }
        }
    }
#endif

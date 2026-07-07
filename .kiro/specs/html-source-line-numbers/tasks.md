# Implementation Plan: HTML Source Line Numbers

## Overview

This implementation adds a line number gutter (NSRulerView subclass) to the HTML source pane in MarkdownReader. The work is broken into creating the new `LineNumberRulerView` class, modifying `SpellCheckingTextEditor` to manage the ruler lifecycle, updating `SourceEditorView` to pass settings through, and adding tests to verify correctness properties.

## Tasks

- [x] 1. Create LineNumberRulerView class
  - [x] 1.1 Create `LineNumberRulerView.swift` with core structure and drawing logic
    - Create file at `Packages/ViewerUI/Sources/ViewerUI/DocumentViewer/LineNumberRulerView.swift`
    - Implement `NSRulerView` subclass with properties: `font`, `textColor` (gray at 0.4 opacity), `currentLineColor` (system accent, full opacity), `currentLine: Int?`, `separatorColor`
    - Implement `init(scrollView:textView:)` that stores references and calls `registerNotifications()`
    - Implement `registerNotifications()` to observe `NSTextStorage.didProcessEditingNotification` and `NSView.boundsDidChangeNotification` on the clip view
    - Implement `lineCount()` that returns `textView.string.components(separatedBy: "\n").count` (minimum 1)
    - Implement `requiredThickness` computed property: calculate width from `max(2, digitCount)` digits at current font size, plus 4pt padding on each side, with a minimum of 36pt
    - Implement `drawHashMarksAndLabels(in:)`: iterate `NSLayoutManager` line fragment rects in the visible rect, draw right-aligned line numbers, draw the 1pt vertical separator at trailing edge, highlight `currentLine` in accent color
    - Guard against nil `layoutManager`/`textContainer` in drawing code
    - _Requirements: 1.1, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 4.1, 4.2_

  - [x] 1.2 Add public API methods for dynamic updates
    - Implement `updateFontSize(_ size: CGFloat)` to update the ruler's font and trigger `needsDisplay = true`
    - Implement `updateCurrentLine(_ line: Int?)` to update highlight and trigger redraw
    - Implement notification handlers `handleTextChange` and `handleScrollChange` that call `needsDisplay = true` and recalculate `requiredThickness` when digit magnitude changes
    - _Requirements: 3.2, 6.2, 6.3_

- [x] 2. Modify SpellCheckingTextEditor to manage ruler lifecycle
  - [x] 2.1 Add line number properties and ruler installation
    - Add `showLineNumbers: Bool` and `lineNumberFontSize: CGFloat` properties to `SpellCheckingTextEditor`
    - Add `rulerView: LineNumberRulerView?` property to `Coordinator`
    - In `makeNSView`, if `showLineNumbers` is true: create `LineNumberRulerView`, set it as `scrollView.verticalRulerView`, set `scrollView.hasVerticalRuler = true`, set `scrollView.rulersVisible = true`
    - Configure ruler font as `NSFont.monospacedSystemFont(ofSize: lineNumberFontSize, weight: .regular)`
    - Set ruler `textColor` to `NSColor.gray.withAlphaComponent(0.4)`, `currentLineColor` to `NSColor.controlAccentColor`, `separatorColor` to `NSColor.separatorColor`
    - _Requirements: 1.1, 1.2, 1.4, 2.4, 6.1_

  - [x] 2.2 Update `updateNSView` for ruler toggling and font size changes
    - In `updateNSView`, check `showLineNumbers`: if true and no ruler exists, create and install it; if false and ruler exists, remove it (set `scrollView.verticalRulerView = nil`, `scrollView.rulersVisible = false`)
    - When ruler exists, call `rulerView.updateFontSize(lineNumberFontSize)` if font size changed
    - When ruler exists, call `rulerView.updateCurrentLine(focusedLine)` to sync highlight
    - Ensure toggling preserves scroll position and text content (no document reload)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 6.2, 6.3_

  - [x] 2.3 Wire focused line updates to ruler
    - In `Coordinator.updateFocusedLine(_:)`, after computing lineNumber, call `rulerView?.updateCurrentLine(lineNumber)`
    - Ensure highlight persists when text view loses focus (do not clear `currentLine` on focus loss)
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 3. Modify SourceEditorView to pass settings
  - [x] 3.1 Pass `showLineNumbers` and `lineNumberFontSize` to SpellCheckingTextEditor
    - Update the `SpellCheckingTextEditor(...)` call in `editorArea` to include `showLineNumbers: coordinator.uiState.showLineNumbers` and `lineNumberFontSize: 11 * themeManager.fontSizeMultiplier`
    - _Requirements: 1.1, 1.2, 6.1, 6.2_

- [x] 4. Checkpoint - Verify core implementation
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Write unit tests for LineNumberRulerView
  - [x]* 5.1 Write unit tests for ruler installation and removal
    - Create test file at `Packages/ViewerUI/Tests/ViewerUITests/LineNumberRulerViewTests.swift`
    - Test: when `showLineNumbers` is true, scroll view has non-nil `verticalRulerView` of type `LineNumberRulerView`
    - Test: when `showLineNumbers` is false, ruler is nil or `rulersVisible` is false
    - Test: font is `NSFont.monospacedSystemFont` at expected size
    - Test: base text color alpha ≤ 0.5, current line color uses accent at full opacity
    - Test: separator is 1pt vertical rule at trailing edge
    - Test: base font size is 11pt, gutter width is 36pt minimum
    - _Requirements: 1.1, 1.2, 1.4, 2.3, 6.1_

  - [x]* 5.2 Write unit tests for current line highlighting
    - Test: setting `currentLine` causes that line number to render in accent color
    - Test: moving cursor updates highlight to new line and reverts previous
    - Test: multi-line selection highlights only insertion point line
    - Test: highlight persists after focus loss
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 6. Write property-based tests
  - [x]* 6.1 Write property test for line count calculation
    - **Property 1: Line count equals newlines plus one**
    - Generate random strings with varying lengths and newline counts (including empty string, trailing newlines, consecutive newlines)
    - Verify: line count == `string.components(separatedBy: "\n").count`, and line count for empty string == 1
    - Minimum 100 iterations
    - **Validates: Requirements 1.3**

  - [x]* 6.2 Write property test for gutter width calculation
    - **Property 2: Gutter width accommodates digit count with minimum of two digits**
    - Generate random line counts in [1, 999999]
    - Verify: `requiredThickness` accommodates `max(2, String(lineCount).count)` digits plus padding, and is never less than 2-digit width
    - Minimum 100 iterations
    - **Validates: Requirements 2.2**

  - [x]* 6.3 Write property test for toggle state preservation
    - **Property 3: Toggle preserves document state**
    - Generate random text content and random valid cursor positions
    - Toggle `showLineNumbers` on/off, verify text content and cursor position are unchanged
    - Minimum 100 iterations
    - **Validates: Requirements 5.3**

  - [x]* 6.4 Write property test for font size scaling
    - **Property 4: Font size scales linearly with multiplier**
    - Generate random multiplier values in [0.5, 3.0]
    - Verify: computed font size == `11.0 * multiplier` within floating-point tolerance
    - Minimum 100 iterations
    - **Validates: Requirements 6.2**

- [x] 7. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific configurations and edge cases
- The implementation uses Swift and targets the ViewerUI package at `Packages/ViewerUI/Sources/ViewerUI/DocumentViewer/`
- Tests go in `Packages/ViewerUI/Tests/ViewerUITests/`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1", "3.1"] },
    { "id": 3, "tasks": ["2.2", "2.3"] },
    { "id": 4, "tasks": ["5.1", "5.2", "6.1", "6.2", "6.3", "6.4"] }
  ]
}
```

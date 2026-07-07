# Requirements Document

## Introduction

This feature adds line number display to the HTML source pane in MarkdownReader. When a user opens an HTML document and views it in source mode, a line number gutter appears alongside the source text if the "Show Line Numbers" setting is enabled. The line numbers help users navigate and reference specific lines in the HTML source.

## Glossary

- **Source_Pane**: The view that displays the raw text content of a document using a monospaced font (implemented by SourceEditorView with SpellCheckingTextEditor wrapping NSTextView).
- **Line_Number_Gutter**: A vertical column displayed to the left of the source text that shows the line number corresponding to each line of content.
- **Show_Line_Numbers_Setting**: A boolean user preference (UIState.showLineNumbers) that controls whether line numbers are visible in content views.
- **HTML_Document**: A document with the .html file format loaded into the application.
- **Current_Line**: The line where the user's text cursor (insertion point) is currently positioned.

## Requirements

### Requirement 1: Display Line Number Gutter for HTML Source

**User Story:** As a developer viewing HTML source, I want to see line numbers next to the source content, so that I can quickly identify and reference specific lines.

#### Acceptance Criteria

1. WHILE the Show_Line_Numbers_Setting is enabled AND an HTML_Document is open in the Source_Pane, THE Source_Pane SHALL display a Line_Number_Gutter to the left of the source text, with line numbers vertically aligned to their corresponding source lines during scrolling.
2. WHILE the Show_Line_Numbers_Setting is disabled, THE Source_Pane SHALL hide the Line_Number_Gutter entirely.
3. THE Line_Number_Gutter SHALL display sequential right-aligned integers starting from 1, with one number per newline-delimited line of the source content, where wrapped portions of the same logical line do not receive a separate line number.
4. THE Line_Number_Gutter SHALL render line numbers using the same monospaced font family as the source text.

### Requirement 2: Line Number Alignment and Sizing

**User Story:** As a user reading HTML source with line numbers, I want the numbers to be visually aligned and not interfere with reading the source, so that the display remains clear and uncluttered.

#### Acceptance Criteria

1. THE Line_Number_Gutter SHALL right-align all line numbers within the gutter column.
2. THE Line_Number_Gutter SHALL maintain a fixed width calculated from the digit count of the highest line number in the document, with a minimum width sufficient to display at least 2 digits, and SHALL update the gutter width when the total line count changes digit magnitude (e.g., from 99 to 100 lines).
3. THE Line_Number_Gutter SHALL display a 1-point vertical rule as a visual separator between the trailing edge of the gutter and the leading edge of the source text content.
4. THE Line_Number_Gutter SHALL render line numbers at no more than 50% opacity relative to the source text color so that line numbers are visually secondary to the source content.
5. THE Line_Number_Gutter SHALL include horizontal padding of at least 4 points between the line number text and the vertical separator.

### Requirement 3: Current Line Highlighting in Gutter

**User Story:** As a user editing HTML source, I want the line number of the line my cursor is on to be visually distinct, so that I can quickly see where I am in the document.

#### Acceptance Criteria

1. WHEN the user places the cursor on a line, THE Line_Number_Gutter SHALL render the Current_Line number in the system accent color at full opacity, visually distinguishing it from the other line numbers which use the subdued color.
2. WHEN the cursor moves to a different line, THE Line_Number_Gutter SHALL apply the accent color to the new Current_Line number and revert the previous Current_Line number to the subdued color, ensuring only one line number is highlighted at any time.
3. IF the user selects text spanning multiple lines, THEN THE Line_Number_Gutter SHALL highlight only the line number where the cursor's insertion point is positioned.
4. IF the Source_Pane loses keyboard focus, THEN THE Line_Number_Gutter SHALL continue to display the last Current_Line highlight until the cursor position changes.

### Requirement 4: Line Number Scrolling Behavior

**User Story:** As a user scrolling through a long HTML document, I want the line numbers to scroll in sync with the source text, so that line numbers always correspond to the adjacent source lines.

#### Acceptance Criteria

1. WHILE the user scrolls the Source_Pane, THE Line_Number_Gutter SHALL scroll vertically in sync with the source text content maintaining zero-pixel vertical offset between each line number and its corresponding source line.
2. WHILE the user scrolls the source text horizontally, THE Line_Number_Gutter SHALL remain horizontally fixed at the leading edge of the Source_Pane.
3. WHEN a programmatic scroll event occurs (e.g., go-to-line navigation), THE Line_Number_Gutter SHALL scroll in sync with the source text to maintain alignment.

### Requirement 5: Toggle Responsiveness

**User Story:** As a user, I want line numbers to appear and disappear immediately when I toggle the setting, so that I get instant feedback on my preference change.

#### Acceptance Criteria

1. WHEN the Show_Line_Numbers_Setting changes from disabled to enabled, THE Source_Pane SHALL display the Line_Number_Gutter within 100 milliseconds without requiring a document reload.
2. WHEN the Show_Line_Numbers_Setting changes from enabled to disabled, THE Source_Pane SHALL hide the Line_Number_Gutter within 100 milliseconds without requiring a document reload.
3. WHEN the Show_Line_Numbers_Setting changes, THE Source_Pane SHALL preserve the current scroll position, cursor location, and any unsaved edits.
4. WHEN the Show_Line_Numbers_Setting changes from disabled to enabled, THE Source_Pane SHALL adjust its layout so that the source text content remains visible without abrupt horizontal shifting of the text already in view.

### Requirement 6: Consistency with Other Format Views

**User Story:** As a user who works with multiple file formats, I want the line number display in the HTML source pane to look consistent with line numbers in other content views, so that the experience feels unified.

#### Acceptance Criteria

1. THE Line_Number_Gutter in the HTML Source_Pane SHALL use the same base font size (11pt), monospaced font design, text color (gray at 0.4 opacity), right-alignment, and gutter width (36pt) as line numbers displayed in the Markdown formatted content view.
2. THE Line_Number_Gutter SHALL scale its base font size by the current theme's font size multiplier setting, so that the displayed line number font size equals 11pt multiplied by the font size multiplier value (range 0.5 to 3.0).
3. IF the font size multiplier changes while the Line_Number_Gutter is visible, THEN THE Line_Number_Gutter SHALL update the displayed font size within the same rendering pass without requiring a document reload.

# Per-Pane Find Bars — Component Spec v1.0

Status: Implemented · Version: 1.0 · Date: 2026-07-07

## Objective
Replace the stubbed sidebar/tab "Search" with in-pane **find bars** (Cmd-F style). Each
pane owns an independent bar that searches only that pane's content and highlights matches
there. macOS: source pane (`NSTextView`) + content pane (rendered markdown). iOS: content
pane only.

## Locked decisions
- Cmd-F opens the focused pane's bar; Esc closes. Bars are independent (separate query/options).
- One global **Find bar position** setting (Top/Bottom), default Top, persisted to `UserDefaults`.
- Platforms: macOS (both panes) + iOS (content pane).
- Features: highlight all matches + emphasize current; match counter `n/m`; next/prev with wrap;
  toggles **Aa** (case-sensitive), **W** (whole-word), **.*** (regex). All toggles default OFF —
  **matching is case-insensitive by default**.
- Content highlight coverage: headings, paragraphs, lists, blockquotes, table cells, code blocks,
  and JSON/XML/plain-text. **HTML and LaTeX previews are out of scope** (unchanged).
- Additive only: the sidebar/tab Search *routing* is removed, but `SearchInterface`, `SearchState`,
  `Search` package, `searchService`, `performSearch`, `uiState.searchVisible` are all preserved.

## Components (as built)
- **C1 `FindState`** (`SearchInterface/FindState.swift`) — observable per-bar state; `FindBarPosition`,
  `FindPane`. Instances `sourceFind`/`contentFind` on `AppStateCoordinator`; `lastFocusedPane`,
  `showFindForFocusedPane()`, `focusedFind`. Position persisted in `UIState.findBarPosition`.
- **C2 `FindMatching`** (`SearchInterface/FindMatching.swift`) — pure matcher via `NSRegularExpression`
  (literal escaped + optional `\b` whole-word; `.caseInsensitive` unless opted in). Zero-length and
  invalid-regex fail closed.
- **C3 `FindBarView`** (`SearchInterface/FindBarView.swift`) — cross-platform bar UI.
- **C4 Content pane** (`DocumentViewer.swift` + `SearchInterface/ContentFindHighlighter.swift`) —
  overlay at configured edge; per-leaf segment model (`seg-<block>[-<item>|-r<row>-c<col>]`, plus
  `structured`) for count/current/scroll; highlight applied to rendered `AttributedString`.
- **C5 Source pane** (`LineNumberTextView.swift` + `SourceEditorView.swift`) — non-destructive
  `NSLayoutManager` temporary-attribute highlight, scroll to current, focus callback.
- **C6/C7 Settings + commands** — position Picker in macOS `MacOSSettingsView` and iOS `SettingsView`;
  Cmd-F / Cmd-G / Shift-Cmd-G on the focused pane; sidebar/tab Search unrouted.

## Acceptance criteria — status
1. Match set/count/highlight scoped to the pane's own content — met (C2/C4/C5).
2. Counter equals highlighted count; `n/m` tracks next/prev with wrap — met (FindStateTests).
3. Regex valid highlights; invalid → "Invalid regex", 0 highlights, no crash — met (FindMatching/Source tests).
4. Case-insensitive by default; Aa/W/regex opt-in change the set correctly — met (FindMatchingTests).
5. Position setting flips both bars and persists across relaunch — met (FindStateTests round-trip).
6. Esc clears highlights; source highlighting never mutates document — met (SourceFindHighlightTests).
7. Cmd-F opens the focused pane's bar — met (coordinator wiring).
8. Existing Outline, heading nav, and prior suites still pass — met (56 pre-existing tests green).

## Tests (all passing)
`FindMatchingTests` (11), `FindStateTests` (8), `SourceFindHighlightTests` (5, macOS),
`ContentFindHighlighterTests` (6) = 30 new. Regression: `CoordinatorFunctionalTests`,
`LineNumberTextViewTests`, `LineNumberPropertyTests`, `LaTeXPreviewTests`,
`DocumentTranslationStateTests` unchanged and passing.

## Known limitations / follow-ups
- Pre-existing (unrelated) failures remain in `DocumentViewerTests` (perf/memory thresholds) and
  `AccessibilityTests` (calls `View.body` directly); not touched by this work.
- Content match navigation scrolls to the match's block anchor (not sub-line centering).
- Structured-text (JSON/XML) find highlights and counts but does not auto-scroll (single Text, no anchors).

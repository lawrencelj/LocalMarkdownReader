# MarkdownReader Change Log

All application and controlled design-document changes are recorded here. Entries are append-only.

## 2026-07-31 — Version 1.0.3 (Build 4)

### Category

- Fix: Translation session lifecycle

### Changes

- Force the markdown/plain-text translation subtree to use the current document identity.
- Ensure SwiftUI creates a fresh `TranslationSession` when translating a second document instead of reusing the completed first-document session.

### Validation

- Translation state tests: 7/7 passed.
- macOS app build: passed.

## 2026-07-31 — Version 1.0.2 (Build 3)

### Category

- Fix: Translation lifecycle

### Changes

- Fixed translation freezing when starting translation for a second document.
- Translation tasks now use a generation guard so cancellation from an older document cannot reset or overwrite the active document's translation state.
- Moved document-change translation reset to the top-level document viewer lifecycle.

### Validation

- Translation state tests: 7/7 passed.
- macOS app build: passed.

## Historical baseline — Version 1.0.0 (Build 1)

This baseline entry records known application and design changes completed before the changelog rule was established:

- Added independent per-pane find bars with case-insensitive-by-default matching, whole-word and regex options, highlighting, navigation, and persisted position settings.
- Replaced the broken line-number ruler implementation with a shared scrolling line-number text view.
- Restored the macOS app icon and release packaging metadata.
- Fixed the CSV/CRLF/HTML-block parser crash by removing the unsafe block-directive parsing path and normalizing line endings.
- Added the find-bars design specification at `Docs/specs/find-bars-v1.0.md`.

## 2026-07-31 — Version 1.0.1 (Build 2)

### Categories

- Feature: Translation
- Fix: macOS sidebar toolbar
- Fix: Translation workflow
- Governance: Project versioning and change tracking

### Changes

- Removed the duplicate macOS sidebar toggle icon.
- Improved translation with incremental batch responses, low-latency strategy when available, language availability checks, cancellation, progress reporting, cancellation-race protection, and disk-backed translation caching.
- Added translation state and cache regression tests.
- Added project rules requiring application version increments and changelog entries for application and controlled design-document changes.

### Affected components

- `Apps/MarkdownReader-macOS/ContentView.swift`
- `Packages/ViewerUI/Sources/ViewerUI/DocumentViewer/DocumentViewer.swift`
- `Packages/ViewerUI/Sources/ViewerUI/DocumentViewer/DocumentTranslationState.swift`
- `Packages/ViewerUI/Tests/ViewerUITests/DocumentTranslationStateTests.swift`
- `Packaging/Info.plist`
- `AGENTS.md`
- `CHANGELOG.md`

### Validation

- Translation state and cache tests: 7/7 passed.
- macOS app build: passed.

## 2026-07-31 — Governance Rule v1.1

### Category

- Governance: Four-suite release and installation gate

### Changes

- Required 100% completion of Unit, Functional, Integration, and Security test suites before release progression.
- Required commit and push of the exact tested revision before application composition.
- Required composition from that pushed revision, verification of the artifact, and force-replacement of `/Applications/Markdown Reader.app` as the final installation step.
- Required launch verification of the installed application.

### Affected components

- `AGENTS.md`
- Release and installation workflow

### Validation

- Rule document version advanced from v1.0 to v1.1.

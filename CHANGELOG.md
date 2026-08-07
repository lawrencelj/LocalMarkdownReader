# MarkdownReader Change Log

All application and controlled design-document changes are recorded here. Entries are append-only.

## 2026-08-07 — Version 1.0.7 (Build 8)

### Category

- Defect fix: table text was never translated

### Changes

- Translated table cells. `translationUnits(in:)` now emits one translation request per non-empty table cell, replacing `translatableText(_:)`, which returned `nil` for `.table` and so silently skipped every table in the document.
- Keyed translations by `TranslationKey` (`"<line>"` for whole blocks, `"<line>#<row>#<column>"` for table cells) instead of by source line alone, since a table's cells all share one source line and could not be addressed individually.
- Changed `DocumentTranslationState.translatedBlocks` and `TranslationCache` from `[Int: String]` to `[String: String]`, and bumped the cache filename suffix to `.v2.json` so v1 entries are re-translated rather than decoded into the wrong shape.
- Rebuilt translated tables cell by cell in `displayedBlock(_:)`; a cell keeps its English text until its own translation arrives, so partial results never distort the grid.
- Skipped table cells containing no letters (numbers, dates, currency) to avoid reformatting numeric values and to reduce request count on data-heavy tables.

### Affected files

- `Packages/ViewerUI/Sources/ViewerUI/DocumentViewer/DocumentTranslationState.swift`
- `Packages/ViewerUI/Sources/ViewerUI/DocumentViewer/DocumentViewer.swift`
- `Packages/ViewerUI/Tests/ViewerUITests/DocumentTranslationStateTests.swift`

### Validation

- Added unit coverage for table-cell key distinctness, per-cell progress accounting, duplicate-response handling, and a cache round trip containing table-cell keys.
- Pending: four-suite verification and a macOS rebuild on the release toolchain.

## 2026-07-31 — Version 1.0.6 (Build 7)

### Category

- Governance: strengthen independent verification evidence

### Changes

- Require separate, candidate-SHA-bound evidence for Unit, Functional, Integration, and Security suites.
- Block aggregate-only test claims and require independent re-acceptance after final documentation or version changes.
- Archived the superseded project rules as `Archive/AGENTS_v1.2.md` and advanced the active rules to v1.3.

### Validation

- Independent verifier previously REJECTED the v1.2 rule for missing SHA rebinding and separate suite evidence.
- Corrective rule changes reviewed locally; four-suite verification must be rerun before closure.

## 2026-07-31 — Version 1.0.5 (Build 6)

### Category

- Governance: independent verification and lessons-learned gate

### Changes

- Added a mandatory post-four-suite independent verifier gate.
- Required rejection handling, evidence-bound acceptance, lessons-learned recording, controlled-document updates, versioning, and push ordering.
- Archived the superseded project rules as `Archive/AGENTS_v1.1.md` and advanced the active rules to v1.2.

### Validation

- Project rules consistency review completed.
- Full available test suite: 269 tests, 0 failures.
- macOS release rebuild completed.

## 2026-07-31 — Version 1.0.4 (Build 5)

### Category

- Documentation and verification: translation lifecycle

### Changes

- Added the translation-session lessons-learned record covering document identity, cancellation, stale-response isolation, and required switching scenarios.
- Recorded independent verification acceptance for translating a second document.

### Validation

- Independent verifier: ACCEPT.
- Focused translation tests: 7/7 passed.
- Full test suite previously passed with 0 failures on the implementation revision.

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

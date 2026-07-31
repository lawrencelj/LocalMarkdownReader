# Translation Session Lessons Learned

**Document Version:** v1.0
**Date:** 2026-07-31
**Scope:** Translation lifecycle when switching between documents

## Lesson

SwiftUI task modifiers can retain asynchronous framework state when the
visible content changes but the view identity does not. Resetting application
state alone is not sufficient to guarantee that a framework-owned session is
created again for the next document.

## Preventive Rule

Any asynchronous task whose lifetime is document-specific must be bound to a
stable document identity. For translation, the rendered Markdown/plain-text
subtree uses the document UUID as its identity. Document changes must also
invalidate the previous request, cancel its session where supported, clear
the active configuration, and reset visible translation state.

## Verification Requirements

Future translation changes must verify all of the following:

1. Translate document A and confirm incremental results complete.
2. Open document B and confirm a new translation starts and completes.
3. Cancel translation, then open another document and confirm translation can
   start normally.
4. Confirm stale responses from document A cannot update document B.
5. Run focused translation tests and the complete available test suite before
   committing.

## Evidence

The document-identity boundary and request-generation checks are implemented
in `Packages/ViewerUI/Sources/ViewerUI/DocumentViewer/DocumentViewer.swift`.
The focused state and cache coverage is in
`Packages/ViewerUI/Tests/ViewerUITests/DocumentTranslationStateTests.swift`.

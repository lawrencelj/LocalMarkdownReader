<!-- Project Rules Version: v1.1 -->

# Project Rules

## Application Versioning

Every change to application source code, application behavior, packaging, tests that affect release behavior, or controlled design/specification documents MUST increment the application version.

- Increment `CFBundleShortVersionString` using semantic versioning. Use the patch component for backward-compatible changes, the minor component for new functionality, and the major component for breaking changes.
- Increment `CFBundleVersion` for every versioned change. It is the monotonically increasing build number.
- A release artifact MUST be composed from the same revision whose version metadata it reports.
- Do not compose or publish an artifact with stale version metadata.

## Change Log

Every application or design/specification change MUST add an entry to the root `CHANGELOG.md` before the change is committed.

Each entry MUST record:

- date
- application version and build number
- change category
- concise description
- affected files or components
- validation performed

The changelog is an operational ledger: append entries in place; do not rewrite or delete prior entries.

## Design Documents

Controlled design and specification documents follow the existing document-control policy:

- increment the document version for every document change
- move the superseded document to `Archive/`
- keep the active document at its fixed live path
- record the change in `CHANGELOG.md`

## Completion Gate

Before closing any application or design change:

1. update the application version when the change affects application behavior or release content
2. append the changelog entry
3. run all related tests
4. rebuild the affected application target
5. verify that the composed artifact reports the new version

## Four-Suite Release and Installation Gate

When a change is ready to close, the release workflow MUST run the complete four-suite gate:

1. Unit tests
2. Functional tests
3. Integration tests
4. Security tests

Every suite MUST complete with a 100% pass result. A skipped suite, unavailable suite, partial run, or ignored failure is not a pass. If the repository maps a suite across multiple test targets, all mapped targets MUST pass.

Only after the four-suite gate passes may the workflow continue:

1. update the changelog and application version
2. commit all intended changes on the current project branch
3. push that exact commit to its configured remote
4. compose the application from that exact pushed revision
5. verify the composed artifact's architecture, signature, icon, plist, and version
6. stop any running copy of the application
7. force-replace `/Applications/Markdown Reader.app` with the newly composed application
8. launch-test the installed application and confirm it remains running

The push, composed artifact, and installed application MUST all correspond to the same commit and application version. If any test suite fails, or if commit/push/composition/install verification fails, do not proceed to the next stage and do not claim the release is complete.

The replacement scope is limited to the exact application bundle path `/Applications/Markdown Reader.app`; no other `/Applications` contents may be removed. When practical, move the existing bundle to the user's Trash before replacement so recovery remains possible.

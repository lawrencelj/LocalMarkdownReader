<!-- Project Rules Version: v1.2 -->

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
- move the superseded document to an `Archive/` folder
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

## Independent Verification and Lessons-Learned Gate

After, and only after, all four suites pass with 100% success, every implementation change MUST enter an independent verification gate:

1. Spawn a second agent or separate agent session that did not implement the change.
2. Give the verifier the user goal and acceptance criteria, not merely the implementation details.
3. Require the verifier to inspect the implementation, attempt the relevant boundary and failure cases, and run the relevant tests.
4. Require an explicit `ACCEPT` or `REJECT` result with evidence tied to the candidate revision.
5. If the result is `REJECT`, correct the issue, rerun all four suites, and repeat independent verification. Do not push or close the change while verification is incomplete or rejected.
6. After `ACCEPT`, review the failure mode and record a concise lessons-learned entry describing the preventive engineering rule and regression checks.
7. Update all affected controlled documents, increment their document versions, archive superseded versions, update the application version and changelog, then commit and push the exact verified revision.

The verifier MUST NOT be the implementing agent or simply rerun the implementer's tests. A test-infrastructure failure is an incomplete verification, not an acceptance; resolve the environment or use an approved reproducible fallback and record the evidence.

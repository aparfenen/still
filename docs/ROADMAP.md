# MVP and release boundaries

Still has a working private development preview. It is not yet a notarized public
beta. The dated evidence and outstanding checks are in QA.md.

## Implemented in the private preview

Manual text/link capture; optional paused-by-default clipboard capture; local SQLite
storage and search; basic offline article snapshots; highlights and dated comments;
folders, tags and categories; reading preferences; recoverable deletion and Undo;
JSON backup/merge import and readable exports; lavender flag app identity.

## Required before normal public distribution

- Complete ordinary-user capture exclusion checks and accessibility/manual QA.
- Obtain Developer ID signing and notarization; verify the final downloaded package
  on a clean Mac with Gatekeeper enabled, using docs/RELEASE.md.
- Record remaining limitations accurately in the tester guide and release notes.

## Subsequent reliability and product work

Improve article extraction with representative fixtures. Benchmark larger libraries,
then paginate and move database work off the UI actor before making capacity claims.
Evaluate a global capture shortcut with platform testing. These features are not
promised by the private preview.

## Later releases

Optional sync requires tested conflicts, account changes, deletion propagation and
offline recovery. Images/PDFs, OCR and reading statistics remain deferred. App Store
distribution additionally requires sandbox validation and submission preparation.

No fabricated delivery dates or capacity claims.

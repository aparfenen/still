# MVP and release boundaries

This is the first executable Mac implementation of Capture → Find → Read →
Highlight → Reuse. It provides a usable development foundation, not a finished
commercial release.

Before public beta:
- Validate on real Mac hardware and resolve manual QA findings.
- Replace basic HTML extraction with a vetted reader and fixture tests.
- Benchmark library sizes, paginate results and move SQLite work off the UI actor.
- Add fuller capture history, recovery UI and safer deletion/undo.
- Add a configurable global capture shortcut if platform testing supports it.
- Build an original icon/artwork system with supplied user assets.
- Add accessibility testing and improve reading typography/settings.

Before App Store release:
- Xcode application project, signing identities and final bundle identifier.
- App Sandbox validation, supported clipboard behavior and network entitlements.
- Distribution signing, privacy disclosures and submission metadata.
- Archive migration/backups and sustained beta evidence.

Next major release:
- Optional iCloud/CloudKit sync with tested conflicts, account changes, deletion
  propagation and offline recovery. Stable IDs already exist; sync is not implemented.
- More original clipboard representations and image/PDF support.
- Reading time estimates and a calm statistics view.

No fabricated delivery dates, capacity claims or editorial-selection guarantees.

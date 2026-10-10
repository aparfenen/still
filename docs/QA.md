# Mac verification checklist

Automated: run `swift test`, then `./scripts/build-app.sh`.
The test suite covers deduplication, metadata preservation, SQLite reopen,
full-text comment search, deletion, retention, archive recovery/atomic rollback,
unsupported archive versions and UTF-16 quotation anchors.

Manual verification on macOS 14+ is still required:

- Fresh launch: empty library, automatic capture off, no existing clipboard imported.
- Save text with emoji and a URL; quit/reopen; original content remains unchanged.
- Search titles, copied text and comments; app/date filters behave as labelled.
- Opt into capture, copy outside Still, pause, copy again; paused copy is not saved.
- Confirm excluded app and concealed/transient clipboard-marker skips.
- Recapture identical content; count updates and notes/status remain intact.
- Fetch a static article; disconnect network; snapshot remains readable.
- Try a JavaScript-only, login-required, large and failing URL; original stays usable.
- Select text, highlight, comment; verify created/edited dates, reopen and share preview.
- Reopen an item after scrolling; reading position restores.
- Export, import into another local library and compare annotations/timestamps.
- Set temporary retention shorter; expired temporary items disappear, manual/kept/
  annotated items remain. UI communicates expiry and destructive shortening.
- Test menu-bar window, ⌘N, ⌘V, ⌘Return, tab navigation and VoiceOver.
- Check light/dark contrast, resizing, multiline titles and long quotations.
- Verify errors never silently reset the database and saved data stays recoverable.
- Verify deleting selected item/annotation requires confirmation.

Not covered by automated storage tests: actual clipboard behavior, native sharing,
article quality, VoiceOver quality, source attribution and interactive rendering.
Do not claim App Store readiness until these checks are completed.

## Local beta validation — October 10, 2026

The Command Line Tools runner passed all 17 storage tests, including soft deletion,
restoration with annotations and organization, 30-day trash expiry, backup round-trip,
and preventing automatic recapture from restoring deleted entries. The release app
built and its ad-hoc signature verified on this Apple silicon Mac.

Using synthetic text only, the native UI saved a passage, highlighted it, added a
comment, deleted it, and restored it from Recently Deleted. The restored item retained
its note and highlight. Quit/reopen retained the record and showed capture paused.
The native save panel exported JSON; the test runner imported that actual file into
a fresh database, reopened it, and compared every item field successfully.

Still pending: final-build UI import and restart verification, actual external-app
clipboard capture/exclusion checks, clean-Mac installation of the notarized ZIP, and
Apple signing/notarization. UI automation became unavailable during the final checks;
this is not evidence that the remaining checks passed. No public-ready claim is made.

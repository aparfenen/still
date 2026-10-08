# Mac verification checklist

Automated: run `swift test`, then `bash scripts/build-app.sh`.
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

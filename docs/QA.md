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

## Private preview verification — October 14, 2026

GitHub Actions run 38081278570 passed the macOS build and storage suite for commit
`de3f042121532f6ea08ed5c26eca2666b8aca8b4`.

Native UI import of the exported JSON succeeded without duplicating the existing
record. Search returned a saved comment and excluded a nonmatching query. A comment
edit survived quit/reopen. Capture stayed paused after restart. A synthetic external
copy was captured after opt-in, while a copy made while paused was ignored.

Source attribution during computer-assisted input reported ChatGPT instead of
TextEdit. Consequently a TextEdit exclusion did not suppress that simulated copy.
This does not validate real-user exclusions or sensitive-marker handling; both
remain pending. Capture was stopped and test-only exclusion settings were restored.

The private-preview ZIP contains only Still.app and READ-ME-FIRST.txt. Packaging
strips resource metadata from a temporary copy, verifies its existing ad-hoc signature,
extracts the ZIP, verifies again, and compares the executable byte-for-byte. The
extracted app launched and displayed capture paused. Deletion and Undo were exercised
in that packaged app: Inbox count decreased, Recently Deleted increased, and Undo
restored the item with Kept status.

User confirmed no Apple Developer membership yet. Developer ID signing, notarization
and a clean-Mac download/install check remain required for normal distribution. The
private preview must not be described as a notarized public beta. No personal library,
preferences, backup, or test record is bundled.

## Clipboard regression and package verification — October 15, 2026

The local Command Line Tools runner passed 20 tests with zero failures: the 17
storage/recovery/export tests and three new clipboard regression tests. The new
tests use unique native NSPasteboard instances with synthetic content, not the
user's general clipboard. They exercise each supported protected marker, excluded
and unknown source identities, self-capture rejection, consuming rejected clipboard
generations, pause/resume baselining, duplicate reads, Unicode, whitespace,
non-text contents, the UTF-8 size limit, and source/pasteboard changes during a read.
Source identities are injected in these tests; this is not an ordinary-user
foreground-app attribution test.

The app now uses that tested reader. It also rechecks protected markers after
reading, in addition to the generation and source checks. No exclusion can prove
which app originally wrote a clipboard payload; foreground attribution remains an
estimate. Unmarked sensitive text from an allowed app can still be captured.

The release app rebuilt successfully. The private-preview ZIP passed archive and
ad-hoc signature verification; the extracted executable matched the built binary
byte for byte (SHA-256):
`af4db82835c09a0b7e005f21b0635419adec373e95ab59b6b6d4b750eb3e7029`.
After quitting Still, the extracted app launched through native UI automation.
Capture showed paused; the existing synthetic passage and its saved comment were
readable. No personal library or preferences are bundled. `git diff --check` passed.
The compiler emitted missing optional Command Line Tools search-path warnings;
compilation, linking and execution nevertheless succeeded.

Remaining gates: an ordinary human copy from an excluded app (automation previously
changed the observed foreground identity), full VoiceOver/manual accessibility QA,
Developer ID signing/notarization, and clean-Mac installation of that notarized
artifact. These are not claimed as passed. The earlier October 10 pending UI import
and restart checks were completed on October 14; see that dated entry.

## Pre-commit review — October 15, 2026

Reviewed the complete pending recovery, clipboard, backup, packaging, workflow and
documentation changes. Fixed backup export to retain folders from the same snapshot
as its selected items while the native save panel is open. Restored validation of
nonnegative annotation locations, positive lengths and nonempty quotations during
import. Added tests proving malformed annotations roll back both items and folders,
and duplicate IDs/originals leave existing data unchanged. The build script now asks
SwiftPM for its binary directory, including when architecture options are supplied.

All 22 local tests passed; the standalone runner includes every XCTest case. Shell,
Python and plist syntax checks and `git diff --check` passed. The release app rebuilt,
and the regenerated preview ZIP passed extraction, signature and executable equality
checks. The final executable SHA-256 is
`7305162e53d3961efc990530b3a1c545cd4d8d9ba97cf0030150e2fd4647746d`.
The extracted app launched with capture paused and exported JSON through its native
save panel. That actual export imported into a fresh temporary database and survived
reopening with all three item records equal field for field. Earlier distribution
and ordinary-user accessibility/exclusion gates remain open; no notarized release
was created by this review.

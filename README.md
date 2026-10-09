# Still 🖤

**Keep what matters.**

A native Mac app for people who collect information while working: designers,
researchers, writers, students, and curious readers.

This repository now contains an early, local-first MVP implementation. It is a
development build, not an App Store release. The compact interface uses a narrow
organization sidebar, a library list, and a calm reader, with system light/dark appearance.

## Run on a Mac

Requires **macOS 14 or later** and Xcode 15+ (or a compatible Swift toolchain).
No third-party package downloads are required; SQLite comes with macOS.

```sh
git clone https://github.com/aparfenen/still.git
cd still
swift test
bash scripts/build-app.sh
open dist/Still.app
```

Or open `Package.swift` in Xcode, select the Still executable, and Run.
The script makes an ad-hoc signed local application bundle. It does not notarize,
distribute, or prepare an App Store submission.

GitHub Actions builds the app and runs storage tests on macOS. A successful run
provides a zipped development app under **Actions → macOS build and storage tests
→ Artifacts → Still-macOS-development**. Download availability requires a GitHub login.
Check the actual run status; a workflow file alone does not prove the checks passed.

## First use

1. Click **+** or press **⌘N**. Paste a link or passage with **⌘V** or Paste clipboard,
   add an optional title, and save with **⌘Return**.
2. Use Inbox, Unread, Kept, or Finished. Search includes text, article snapshots,
   quotations, and comments. Filter by likely source app or the last seven days.
3. For a link, choose **Prepare reader** to fetch a basic offline snapshot.
   Unsupported pages retain their original link; open it in your browser.
4. Select words and choose **Highlight**. Open notes to add a timestamped comment.
   An annotated item is retained automatically.
5. **Keep** uses the heart to prevent temporary history from expiring.
   Manual saves already stay until deleted. Use **Organize…** to assign a folder, category, and comma-separated tags.
6. Copy the original, share it, or preview and share an attributed highlight.
   Comments are excluded from excerpt sharing unless selected.
7. Opt into **automatic capture** through the menu bar or Capture preferences.
   It starts paused by default and never imports the old clipboard on activation.

## How long are items stored?

| Item | Retention |
|---|---|
| Manually pasted and saved items | Until you delete them |
| Automatic clipboard captures | **7 days by default**, measured from the latest copy of the same content |
| Kept, highlighted, commented, or organized items | No automatic expiry |

Change temporary retention in **Settings → Capture** to **1, 7, or 30 days**.
Assigning a folder, tag, or category keeps an item from expiring.
Shortening retention removes temporary items that are already past the new limit.
Expired items are removed at launch, about hourly while Still runs, and when
retention changes. Still does not remove expired items while it is closed.

## Choosing an export format

Use **Export library** in the sidebar for everything, or **Export** in the reader
for one item.

| Purpose | Recommended format |
|---|---|
| A complete backup you can restore into Still | **JSON backup** |
| Writing, reusable notes, or moving content to another notes app | **Markdown** |
| Browsing or analyzing items in a spreadsheet | **CSV** |
| A readable document to open in a browser | **HTML** |
| Simple text you can open almost anywhere | **Plain text (TXT)** |

**Recommended routine:** save a JSON backup regularly; use Markdown when taking
notes elsewhere. JSON preserves saved content, annotations and timestamps,
organization, and folders (including empty folders). Only JSON can be imported
back into Still; the other formats are readable exports.

All exports include saved text, highlights, and comments. Keep private backups
somewhere you trust. Import through **Settings → Capture → Import backup…** or
**Library → Import Library…**. Imports merge new items; existing items with the
same ID or original content are preserved rather than overwritten.

## Interface and organization

- Lavender bookmark-shaped flag beside **still**, with a matching Dock/Finder icon.
- **Settings → Reading**: system/serif/rounded/monospaced font, size, spacing, margins, and light/dark/system appearance.
- Create, rename, or delete folders through the sidebar **+**. Deleting a folder keeps its items.
- **Organize…** in the reader or item context menu assigns one folder, one category, and multiple tags.
- Folder, tag, and category sidebar filters; tags/categories also participate in search.
- Export the whole library or one item as JSON, Markdown, CSV, TXT, or HTML. Exports include comments.
- JSON is the restore format, including empty folders. Other formats are readable exports, not backups.
- Older libraries and version-1 JSON archives migrate without resetting saved content.

## Included

- Native SwiftUI app, menu bar controls, keyboard-friendly manual capture.
- Optional plain-text/link clipboard polling, exclusions and sensitive markers.
- Exact-content deduplication with count and latest capture time.
- SQLite transactions, WAL durability and FTS5 prefix search.
- Offline local library, dated items, status counters and source/date filters.
- Passive basic article extraction (no remote JavaScript execution).
- Native text selection, quotation-verified highlights, dated comments.
- Restored reading scroll position, read/unread/finished states.
- Native sharing with a preview for annotated excerpts.
- Versioned JSON backup plus Markdown/CSV/TXT/HTML export and atomic merge import.
- Temporary retention, default seven days; manual/kept/annotated/organized items do not expire.
- Storage tests and a macOS build workflow.

## Deliberately deferred

iCloud sync, rich clipboard formats, images/PDFs, OCR, detailed statistics and
reading timers, global configurable hotkeys, mobile apps and AI.
The current shortcuts work inside Still; this version does not register a system-wide hotkey.
Large-library performance has not been benchmarked: SQLite search is indexed, but
the UI currently loads item metadata/payloads into memory. Pagination/background
database work must precede any claim of 100,000-item performance.

Source labels say **Likely**: the frontmost app is an estimate, not proof of origin.
Clipboard polling can miss rapid copies and cannot capture everything from every app.
The reader is a conservative HTML extractor, not a production Readability engine;
some sites need sign-in, JavaScript, or extraction improvements.

## Data and privacy

The library is at `~/Library/Application Support/Still/library.sqlite`, alongside
SQLite WAL files. Do not copy a live SQLite file as a backup; use **Export Library**.
Exports include your saved text and comments in plain JSON: store and share them carefully.
Imports merge new items; existing IDs or identical originals win, preserving their
current content. Imports never overwrite existing annotations.

No analytics, cloud uploads or AI requests. The only app-initiated network request is
an article fetch you explicitly start; opening originals and native sharing are your
actions. The SQLite library is not application-encrypted; macOS account permissions
restrict the directory. FileVault protection is managed by macOS, not Still.

See [privacy details](docs/PRIVACY.md), [manual QA](docs/QA.md) and
[release boundaries](docs/ROADMAP.md).

## Design direction

Working name: Still. Calm ivory, native controls, subtle highlights, and a meaningful
heart for Keep, and a lavender flag for the app identity. The actual user's artwork has not been supplied; no invented art is
presented as theirs.

[Compact visual concepts](https://canva.link/px2nevo90jok8wj) ·
[MVP concept document](https://canva.link/95lgs20dq53bp0o)

The implementation follows the direction of those static concepts, rather than
claiming pixel-for-pixel fidelity.

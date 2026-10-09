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

## Interface and organization\n\n- Lavender filled flag beside **still**, with a matching Dock/Finder icon.\n- **Settings → Reading**: system/serif/rounded/monospaced font, size, spacing, margins, and light/dark/system appearance.\n- Create, rename, or delete folders through the sidebar **+**. Deleting a folder keeps its items.\n- **Organize…** in the reader or item context menu assigns one folder, one category, and multiple tags.\n- Folder, tag, and category sidebar filters; tags/categories also participate in search.\n- Export the whole library or one item as JSON, Markdown, CSV, TXT, or HTML. Exports include comments.\n- JSON is the restore format, including empty folders. Other formats are readable exports, not backups.\n- Older libraries and version-1 JSON archives migrate without resetting saved content.\n\n## Included

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

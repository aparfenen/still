# Install the development preview

Use the public repository's **Releases** page and download **Still.dmg**.
Release assets have stable direct links and do not require a GitHub login for this
public repository. Do not save a browser error page or an expired temporary link
and rename it to ZIP.

1. Download Still.dmg using Safari or Chrome.
2. Double-click it in Finder. It is a disk image, not a ZIP; no unzip tool is needed.
3. Drag Still.app to the Applications shortcut.
4. Eject the Still disk image and open Still from Applications.

Requires Apple silicon and macOS 14+. This development build is ad-hoc signed,
not notarized. If macOS prevents opening it, check System Settings > Privacy &
Security after the first launch attempt. Do not disable Gatekeeper globally.

Alternative: download the release asset Still-macOS.zip and expand it once with
macOS Archive Utility. The release ZIP directly contains Still.app. GitHub Actions
artifacts add their own outer ZIP; release assets do not.

The workflow tests ZIP integrity and extraction, creates and verifies the DMG,
mounts it read-only, and checks the application signature and executable. Checksums
are published as SHA256SUMS.txt. These checks verify packaging, not interactive
application behavior or App Store eligibility.

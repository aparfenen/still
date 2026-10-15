# Public beta release procedure

The public beta is not published yet. Local artifacts are ad-hoc signed development
builds. Never promote the Actions artifacts directly to a public beta release.

## Prerequisites

Use macOS 14 or newer with a compatible Swift toolchain, an installed **Developer ID
Application** certificate with its private key, and an existing `notarytool` Keychain
profile. Configure signing credentials locally; do not put them in source control or
chat. The publishing script also requires authenticated GitHub CLI access.

Commit the reviewed source, pass CI and local QA, then run:

```sh
export STILL_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export STILL_NOTARY_PROFILE='your-existing-keychain-profile'
./scripts/release.sh
```

This runs storage tests, builds with hardened runtime and a timestamped signature,
submits a ZIP for notarization, requires Apple's Accepted result, staples the app,
and verifies Gatekeeper acceptance before making the final ZIP and checksum. It
records the source commit. Keep credentials and notarization logs private.

The default is Apple silicon. `STILL_UNIVERSAL=1` requests both architectures;
verify the resulting executable and test on Intel before advertising Intel support.

## Clean-install gate

Download or copy the final ZIP onto a Mac with no prior Still installation. Expand
it in Finder, drag Still to Applications, and open it with normal Gatekeeper enabled.
Verify paused capture, save, search, annotation/comment editing, deletion and restore,
JSON export/import, and quit/reopen. Confirm the exported ZIP itself is the tested
artifact. A development-machine launch does not replace this check.

Tag the verified source as `v0.1.0-beta.1` and push that tag. Then:

```sh
export STILL_GITHUB_REPO=aparfenen/still
export STILL_CLEAN_INSTALL_VERIFIED=yes
./scripts/publish.sh
```

Publication verifies the extracted ZIP's stapled ticket and Gatekeeper status,
checksum, clean source tree, source commit and release tag. It creates a prerelease
with the ZIP and checksum. Do not set the QA flag until the installation check passes.

If signing or notarization is unavailable, keep the build local and report the
missing prerequisite. Do not ask users to disable macOS security protections.

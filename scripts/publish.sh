#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
: "${STILL_GITHUB_REPO:?Set owner/repository}"
: "${STILL_CLEAN_INSTALL_VERIFIED:?Set to yes after clean-install QA on the notarized ZIP}"
[[ "$STILL_CLEAN_INSTALL_VERIFIED" == yes ]] || exit 1
command -v gh >/dev/null
stage=$(mktemp -d /private/tmp/still-release-check.XXXXXX)
trap 'rm -rf "$stage"' EXIT
ditto -x -k dist/Still-0.1.0-beta.1-macOS.zip "$stage"
xcrun stapler validate "$stage/Still.app"
spctl --assess --type execute "$stage/Still.app"
[[ "$(cat dist/RELEASE-COMMIT)" == "$(git rev-parse HEAD)" ]] || { print -u2 "Rebuild from the current release commit."; exit 1; }
(cd dist && shasum -a 256 -c <(sed 's@dist/@@g' SHA256SUMS))
git diff --quiet && git diff --cached --quiet
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] || { print -u2 'Commit the complete reviewed release source first.'; exit 1; }
[[ "$(git rev-parse HEAD)" == "$(git rev-parse v0.1.0-beta.1^{commit})" ]] || { print -u2 'Release tag must point to the reviewed HEAD.'; exit 1; }
gh release create v0.1.0-beta.1 dist/Still-0.1.0-beta.1-macOS.zip dist/SHA256SUMS --repo "$STILL_GITHUB_REPO" --verify-tag --prerelease --title 'Still — Public Beta v0.1' --notes-file docs/RELEASE-NOTES.md

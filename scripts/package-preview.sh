#!/bin/zsh
# Package the already-tested app; do not imply Developer ID or notarization.
set -euo pipefail
cd "${0:A:h:h}"
stage=$(mktemp -d /private/tmp/still-preview.XXXXXX)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/package" "$stage/check" dist
# Avoid Finder/iCloud resource metadata in the distributable bundle.
ditto --norsrc --noextattr dist/Still.app "$stage/package/Still.app"
codesign --verify --strict "$stage/package/Still.app"
cmp dist/Still.app/Contents/MacOS/Still "$stage/package/Still.app/Contents/MacOS/Still"
cp docs/FRIENDS-PREVIEW.txt "$stage/package/READ-ME-FIRST.txt"
archive="$PWD/dist/Still-0.1.0-private-preview-arm64.zip"
ditto --norsrc --noextattr -c -k "$stage/package" "$archive"
unzip -t "$archive" >/dev/null
ditto --norsrc --noextattr -x -k "$archive" "$stage/check"
codesign --verify --strict "$stage/check/Still.app"
cmp dist/Still.app/Contents/MacOS/Still "$stage/check/Still.app/Contents/MacOS/Still"
(cd dist && shasum -a 256 Still-0.1.0-private-preview-arm64.zip > Still-0.1.0-private-preview-arm64.sha256)
print "Verified private preview: $archive"

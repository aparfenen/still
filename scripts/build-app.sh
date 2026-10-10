#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
args=()
if [[ "${STILL_UNIVERSAL:-0}" == 1 ]]; then args=(--arch arm64 --arch x86_64); fi
./scripts/swift.sh build -c release --product Still -debug-info-format none "${args[@]}"
stage=$(mktemp -d /private/tmp/still-beta.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/Still.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" dist
cp -X .build/release/Still "$app/Contents/MacOS/Still"
cp -X Resources/Info.plist "$app/Contents/Info.plist"
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift scripts/generate-icon.swift "$stage/Still.iconset"
# Package PNG representations directly; no third-party image dependency.
python3 scripts/package-icon.py "$stage/Still.iconset" "$app/Contents/Resources/Still.icns"
identity="${STILL_SIGN_IDENTITY:--}"
if [[ "$identity" == "-" ]]; then
    codesign --force --sign - "$app"
else
    [[ "$identity" == 'Developer ID Application:'* ]] || { print -u2 'A Developer ID Application certificate is required.'; exit 1; }
    codesign --force --sign "$identity" --options runtime --timestamp "$app"
fi
codesign --verify --strict "$app"
if [[ -d dist/Still.app ]]; then
    mkdir -p dist/previous
    mv dist/Still.app "dist/previous/Still-$(date +%Y%m%d-%H%M%S).app"
fi
ditto --norsrc "$app" dist/Still.app
codesign --verify --strict dist/Still.app
print "Built $PWD/dist/Still.app"

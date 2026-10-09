#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
STILL_BIN_DIR="$(swift build -c release --show-bin-path)"
STILL_APP_DIR="$PWD/dist/Still.app"
mkdir -p "$STILL_APP_DIR/Contents/MacOS" "$STILL_APP_DIR/Contents/Resources"
cp "$STILL_BIN_DIR/Still" "$STILL_APP_DIR/Contents/MacOS/Still"
cp Resources/Info.plist "$STILL_APP_DIR/Contents/Info.plist"
swift scripts/generate-icon.swift "$PWD/dist/Still.iconset"
iconutil -c icns "$PWD/dist/Still.iconset" -o "$STILL_APP_DIR/Contents/Resources/Still.icns"
codesign --force --sign - "$STILL_APP_DIR"
printf 'Built %s\n' "$STILL_APP_DIR"

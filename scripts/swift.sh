#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/module-cache .build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
# Disable SwiftPM's nested manifest sandbox; the host still applies its own sandbox.
swift "$@" --disable-sandbox --cache-path .build/cache --scratch-path .build

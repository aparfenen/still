#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
STILL_STANDALONE_TESTS=1 ./scripts/swift.sh build --product StillCoreChecks
.build/debug/StillCoreChecks

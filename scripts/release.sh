#!/bin/zsh
# Creates a verified distribution artifact. It never publishes automatically.
set -euo pipefail
cd "${0:A:h:h}"
: "${STILL_SIGN_IDENTITY:?Set the installed Developer ID Application certificate name}"
: "${STILL_NOTARY_PROFILE:?Set the existing notarytool Keychain profile name}"
[[ "$STILL_SIGN_IDENTITY" == 'Developer ID Application:'* ]] || exit 1
xcrun notarytool history --keychain-profile "$STILL_NOTARY_PROFILE" >/dev/null
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] || { print -u2 "Commit release source before building."; exit 1; }
git rev-parse HEAD > /dev/null
./scripts/test-local.sh
./scripts/build-app.sh
app="$PWD/dist/Still.app"
submission="$PWD/dist/Still-notarization.zip"
ditto -c -k --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --keychain-profile "$STILL_NOTARY_PROFILE" --wait --output-format json > dist/notarization.json
python3 - <<'PY'
import json
from pathlib import Path
result = json.loads(Path('dist/notarization.json').read_text())
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted. Do not publish this build.')
PY
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --strict "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --keepParent "$app" dist/Still-0.1.0-beta.1-macOS.zip
shasum -a 256 dist/Still-0.1.0-beta.1-macOS.zip > dist/SHA256SUMS
git rev-parse HEAD > dist/RELEASE-COMMIT
print 'Notarized ZIP prepared. Complete clean-install QA before publishing.'

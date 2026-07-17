#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
: "${HEADROOM_CODESIGN_IDENTITY:?Set HEADROOM_CODESIGN_IDENTITY to a Developer ID Application certificate name}"
: "${HEADROOM_NOTARY_PROFILE:?Create an xcrun notarytool keychain profile and set HEADROOM_NOTARY_PROFILE}"

export HEADROOM_CODESIGN_IDENTITY
"$ROOT/scripts/package-app.sh" release
DMG="$($ROOT/scripts/create-dmg.sh)"

xcrun notarytool submit "$DMG" --keychain-profile "$HEADROOM_NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo "$DMG"

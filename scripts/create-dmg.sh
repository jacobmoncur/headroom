#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Headroom.app"
DMG="$ROOT/dist/Headroom-0.3.0.dmg"

[[ -d "$APP" ]] || "$ROOT/scripts/package-app.sh" release
rm -f "$DMG"
hdiutil create -volname "Headroom" -srcfolder "$APP" -ov -format UDZO "$DMG"

if [[ -n "${HEADROOM_CODESIGN_IDENTITY:-}" && "$HEADROOM_CODESIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$HEADROOM_CODESIGN_IDENTITY" "$DMG"
fi

echo "$DMG"

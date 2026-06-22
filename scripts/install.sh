#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Build the release .app bundle.
scripts/package.sh

APP="SportNotch.app"
DEST="/Applications"

if [ ! -w "$DEST" ]; then
    echo "Error: $DEST is not writable. Re-run with: sudo scripts/install.sh" >&2
    exit 1
fi

# Replace any existing install with the fresh bundle.
rm -rf "$DEST/$APP"
cp -R "$APP" "$DEST/$APP"

# Strip quarantine so a locally built, unsigned app opens without the
# "unidentified developer" Gatekeeper prompt.
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

echo "Installed $DEST/$APP"
echo "Launch it from Launchpad or /Applications. Quit via the soccerball menu bar icon → Quit Sport Notch."

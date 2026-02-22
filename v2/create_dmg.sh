#!/bin/bash
# Create a DMG for ThinLinc Connection Manager (run after build.sh).
# Output: v2/ThinLinc-Connection-Manager.dmg — ready to copy or share.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="ThinLinc Connection Manager"
APP_PATH="build/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="ThinLinc-Connection-Manager"
DMG_PATH="$SCRIPT_DIR/${DMG_NAME}.dmg"
STAGING="$SCRIPT_DIR/dmg_staging"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found. Run ./build.sh first."
  exit 1
fi

echo "Creating DMG..."
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Create read-only DMG (no fancy layout — simple and reliable)
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -fs HFS+ "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "Created: $DMG_PATH"
echo "Share this file; recipients open it and drag the app to Applications."

#!/bin/bash
# Build ThinLinc Connection Manager as a universal binary (Intel + Apple Silicon).
# Requires Xcode (not just Command Line Tools). Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SCHEME="ThinLincConnectionManager"
PROJECT="ThinLincConnectionManager.xcodeproj"
CONFIG="${1:-Release}"

echo "Building $SCHEME ($CONFIG) for arm64 + x86_64..."
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath build \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  ENABLE_PREVIEWS=NO \
  build

APP_PATH="build/Build/Products/$CONFIG/ThinLinc Connection Manager.app"
if [[ -d "$APP_PATH" ]]; then
  echo ""
  echo "Built: $APP_PATH"
  echo "Copy this .app to another Mac, or run ./create_dmg.sh to create a DMG for easy sharing."
fi

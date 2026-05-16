#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Agent Rocky"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/AgentRocky.dmg"

cd "$ROOT_DIR"

swift test
scripts/package-macos-app.sh
scripts/create-dmg.sh

plutil -lint "$APP_PATH/Contents/Info.plist"

if command -v codesign >/dev/null 2>&1; then
  codesign --verify --deep --strict "$APP_PATH"
fi

hdiutil verify "$DMG_PATH"
echo "Release artifacts ready:"
echo "$APP_PATH"
echo "$DMG_PATH"

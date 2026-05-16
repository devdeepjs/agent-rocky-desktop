#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Agent Rocky"
BUNDLE_ID="dev.agentrocky.desktop"
PRODUCT_NAME="AgentRocky"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
TMP_APP="$DIST_DIR/.$APP_NAME.app.tmp"
INSTALL_TARGET="${INSTALL_TARGET:-}"

usage() {
  cat <<USAGE
Usage:
  scripts/package-macos-app.sh
  scripts/package-macos-app.sh --install

Builds dist/$APP_NAME.app. With --install, copies it to /Applications when
writable, otherwise ~/Applications.
USAGE
}

INSTALL=0
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
elif [[ "${1:-}" == "--install" ]]; then
  INSTALL=1
elif [[ $# -gt 0 ]]; then
  usage >&2
  exit 2
fi

cd "$ROOT_DIR"
swift build -c release --product "$PRODUCT_NAME"

rm -rf "$TMP_APP"
mkdir -p "$TMP_APP/Contents/MacOS" "$TMP_APP/Contents/Resources"
cp "$ROOT_DIR/.build/release/$PRODUCT_NAME" "$TMP_APP/Contents/MacOS/$PRODUCT_NAME"
swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$TMP_APP/Contents/Resources/AppIcon.icns"

cat > "$TMP_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$TMP_APP" >/dev/null
fi

rm -rf "$APP_PATH"
mv "$TMP_APP" "$APP_PATH"
echo "Built $APP_PATH"

if [[ "$INSTALL" -eq 1 ]]; then
  if [[ -n "$INSTALL_TARGET" ]]; then
    TARGET_DIR="$INSTALL_TARGET"
  elif [[ -w "/Applications" ]]; then
    TARGET_DIR="/Applications"
  else
    TARGET_DIR="$HOME/Applications"
  fi

  mkdir -p "$TARGET_DIR"
  TARGET_APP="$TARGET_DIR/$APP_NAME.app"
  TMP_TARGET="$TARGET_DIR/.$APP_NAME.app.tmp"
  rm -rf "$TMP_TARGET"
  cp -R "$APP_PATH" "$TMP_TARGET"
  rm -rf "$TARGET_APP"
  mv "$TMP_TARGET" "$TARGET_APP"
  echo "Installed $TARGET_APP"
fi

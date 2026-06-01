#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AudioInput"
BUNDLE_ID="com.audioinput.app"
VERSION="0.1.0"
SIGN_IDENTITY="${SIGN_IDENTITY:-AudioInput Local Code Signing}"
SIGN_KEYCHAIN="${SIGN_KEYCHAIN:-$HOME/Library/Keychains/audioinput-signing.keychain-db}"
BUILD_DIR="$(pwd)/.build"
DIST_DIR="$(pwd)/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"
PLIST_PATH="$CONTENTS_DIR/Info.plist"

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
if [ -f "$(pwd)/Assets/AppIcon.icns" ]; then
  cp "$(pwd)/Assets/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>AudioInput 需要麦克风权限用于语音转文字。</string>
</dict>
</plist>
PLIST

if security find-certificate -c "$SIGN_IDENTITY" "$SIGN_KEYCHAIN" >/dev/null 2>&1; then
  security unlock-keychain -p audioinput "$SIGN_KEYCHAIN" >/dev/null 2>&1 || true
  codesign --force --sign "$SIGN_IDENTITY" --keychain "$SIGN_KEYCHAIN" --identifier "$BUNDLE_ID" "$APP_DIR"
else
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR"
fi

echo "Packaged app: $APP_DIR"

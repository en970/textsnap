#!/bin/bash
# Builds the TextSnapBar menu bar companion and packages it as a runnable .app bundle.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP_NAME="TextSnapBar"
APP_DIR="$APP_NAME.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>TextSnapBar</string>
    <key>CFBundleDisplayName</key>
    <string>textsnap</string>
    <key>CFBundleIdentifier</key>
    <string>me.kouh.textsnap.menubar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>TextSnapBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc signing (`--sign -`) derives its identity from the binary's hash, so it changes on
# every rebuild -- macOS then treats each build as a brand new app and re-prompts for Screen
# Recording every time. Signing with a real local identity keeps that identity stable across
# rebuilds, so permission grants persist. Prefer a local "Apple Development" identity (what
# Xcode uses for on-device/local runs) if one is available; fall back to ad-hoc otherwise.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -m1 "Apple Development" \
    | sed -E 's/^[[:space:]]*[0-9]+\) [A-F0-9]+ "(.*)"$/\1/')

if [ -z "$IDENTITY" ]; then
    IDENTITY="-"
    echo "No local 'Apple Development' signing identity found in Keychain -- falling back to ad-hoc signing."
    echo "Ad-hoc identities change on every rebuild, so macOS will re-prompt for Screen Recording each time."
    echo "Open Xcode once (any project) to get a free local 'Apple Development' identity, then rebuild."
else
    echo "Signing with local identity: $IDENTITY"
fi

codesign --force --deep --sign "$IDENTITY" "$APP_DIR"

echo "Built $APP_DIR"

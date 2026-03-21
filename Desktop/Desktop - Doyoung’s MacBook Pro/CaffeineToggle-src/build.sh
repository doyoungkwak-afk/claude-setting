#!/bin/bash
set -e

TEAM_ID="KTF6SP2F85"
CERT="Apple Development: kdo4789@naver.com (QGG32885U3)"
APP_NAME="CaffeineToggle"
BUNDLE="$HOME/Applications/${APP_NAME}.app"

echo "▶ Compiling..."
swiftc -parse-as-library \
    -target arm64-apple-macosx14.0 \
    -framework SwiftUI -framework AppKit -framework ServiceManagement \
    main.swift \
    -o "$APP_NAME"

echo "▶ Deploying to $BUNDLE..."
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"
cp "$APP_NAME"   "$BUNDLE/Contents/MacOS/$APP_NAME"
cp Info.plist    "$BUNDLE/Contents/Info.plist"

if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "▶ Signing..."
codesign --force --sign "$CERT" \
    --options runtime \
    "$BUNDLE"

echo "▶ Launching..."
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.3
open "$BUNDLE"
sleep 3
pgrep -x "$APP_NAME" && echo "✓ Running!" || echo "✗ Failed to start"

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

# Generate the app icon if it's missing (committed normally; this keeps a fresh
# checkout buildable without the asset).
if [ ! -f "Resources/AppIcon.icns" ]; then
    swift scripts/make-appicon.swift
fi

APP="FootballNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/FootballNotch" "$APP/Contents/MacOS/FootballNotch"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
echo "Built $APP"

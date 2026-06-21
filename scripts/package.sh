#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP="FootballNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/FootballNotch" "$APP/Contents/MacOS/FootballNotch"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
echo "Built $APP"

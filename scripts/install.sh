#!/bin/bash
# Builds a Release version of Kontrollglid and installs it in /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild -project Kontrollglid.xcodeproj -scheme Kontrollglid -configuration Release \
  -derivedDataPath build build | tail -1

osascript -e 'tell application id "se.matalve.Kontrollglid" to quit' 2>/dev/null || true
rm -rf /Applications/Kontrollglid.app
cp -R build/Build/Products/Release/Kontrollglid.app /Applications/
open /Applications/Kontrollglid.app
echo "Installed /Applications/Kontrollglid.app"

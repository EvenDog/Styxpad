#!/bin/bash
# Builds TartarusMac and packages it as a real Mac app (build/TartarusMac.app).
# A proper .app bundle (instead of a bare program) is needed so macOS can remember
# the Input Monitoring / Accessibility permissions you grant it.

set -euo pipefail          # stop immediately if any step fails
cd "$(dirname "$0")"       # run from the project folder no matter where you call this from

swift build -c release

APP="build/TartarusMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TartarusMac "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

# Sign with your Apple Development certificate. A stable signature means macOS
# keeps your granted permissions after each rebuild.
codesign --force --sign "Apple Development" "$APP"

echo "Built $APP — launch it with: open $APP"

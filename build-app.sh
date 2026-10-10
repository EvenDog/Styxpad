#!/bin/bash
# Builds Styxpad and packages it as a real Mac app (build/Styxpad.app).
# A proper .app bundle (instead of a bare program) is needed so macOS can remember
# the Input Monitoring / Accessibility permissions you grant it.

set -euo pipefail          # stop immediately if any step fails
cd "$(dirname "$0")"       # run from the project folder no matter where you call this from

swift build -c release

APP="build/Styxpad.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Styxpad "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"   # the app icon (made by Design/make-icon.swift)

# Sign with your Apple Development certificate. A stable signature means macOS
# keeps your granted permissions after each rebuild.
codesign --force --sign "Apple Development" "$APP"

echo "Built $APP — launch it with: open $APP"

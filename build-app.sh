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
BINARY="$(swift build -c release --show-bin-path)/Styxpad"
cp "$BINARY" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"   # the app icon (made by Design/make-icon.swift)

# Match the installed release's identity so testing doesn't replace its permissions.
# Override explicitly with SIGNING_IDENTITY for another developer's certificate.
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
bash Tools/embed-sparkle.sh "$APP" "$SIGNING_IDENTITY"
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

echo "Built $APP — launch it with: open $APP"

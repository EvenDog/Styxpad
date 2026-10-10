#!/bin/bash
# Packs an app into a styled DMG: when opened, the window shows the Styx background with an arrow,
# Styxpad on the left and an Applications shortcut on the right, so people drag one onto the other.
#
# Usage: ./make-dmg.sh path/to/Styxpad.app path/to/output.dmg
# (make-release.sh calls this; you can also run it on its own to try out the layout.)
#
# The first time, macOS asks whether Terminal may control Finder — allow it: Finder is what
# saves the window layout (background, icon positions) into the DMG.

set -euo pipefail
cd "$(dirname "$0")"

APP="$1"
DMG="$2"
WORK=$(mktemp -d)

# Window content size and icon centers — the same numbers as in Design/make-dmg-background.swift.
WIDTH=640
HEIGHT=400
APP_X=165; APP_Y=205
APPLICATIONS_X=475; APPLICATIONS_Y=205

echo "==> Drawing the DMG background"
swiftc -O Design/make-dmg-background.swift -o "$WORK/make-background"
"$WORK/make-background" "$WORK/background.png" "$WORK/background@2x.png"

echo "==> Preparing the DMG contents"
mkdir -p "$WORK/staging/.background"   # a folder starting with "." is hidden in Finder
# Combine the normal and Retina images into one file, so the background is sharp on every screen.
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/staging/.background/background.tiff"
cp -R "$APP" "$WORK/staging/"
ln -s /Applications "$WORK/staging/Applications"

echo "==> Laying out the window"
# First a writable DMG, so Finder can save the layout into it.
hdiutil create -volname "Styxpad" -srcfolder "$WORK/staging" -fs HFS+ -format UDRW -ov "$WORK/writable.dmg" >/dev/null
MOUNT=$(hdiutil attach -readwrite -noverify -noautoopen "$WORK/writable.dmg" | grep -o '/Volumes/.*$')
VOLUME=$(basename "$MOUNT")   # usually "Styxpad" (or "Styxpad 1" if another one is already open)

# AppleScript (macOS's built-in automation language) tells Finder how the window should look.
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        try
            set pathbar visible of container window to false
        end try
        -- The bounds include the title bar (about 32 points), so add it to the content height.
        set bounds of container window to {200, 120, 200 + $WIDTH, 120 + $HEIGHT + 32}
        set options to the icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 112
        set text size of options to 13
        set background picture of options to file ".background:background.tiff"
        set position of item "$(basename "$APP")" of container window to {$APP_X, $APP_Y}
        set position of item "Applications" of container window to {$APPLICATIONS_X, $APPLICATIONS_Y}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

sync   # make sure Finder's saved layout is written to the disk image
hdiutil detach "$MOUNT" -quiet

echo "==> Compressing the DMG"
rm -f "$DMG"
hdiutil convert "$WORK/writable.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf "$WORK"
echo "Made $DMG"

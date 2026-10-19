#!/bin/bash
# Copies Sparkle into a packaged app and signs the nested helpers from the inside out.
# Usage: bash Tools/embed-sparkle.sh path/to/App.app "Developer ID Application"
set -euo pipefail
APP_PATH="$1"
SIGNING_IDENTITY="$2"
SPARKLE_SOURCE=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
SPARKLE_DEST="$APP_PATH/Contents/Frameworks/Sparkle.framework"

test -d "$SPARKLE_SOURCE" || { echo "Build with Swift Package Manager first." >&2; exit 1; }
mkdir -p "$APP_PATH/Contents/Frameworks" "$APP_PATH/Contents/Resources"
ditto "$SPARKLE_SOURCE" "$SPARKLE_DEST"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$APP_PATH/Contents/Resources/Sparkle-LICENSE.txt"

# Styxpad isn't sandboxed, so it doesn't use Sparkle's sandbox-only XPC services.
rm -rf "$SPARKLE_DEST/Versions/B/XPCServices" "$SPARKLE_DEST/XPCServices"
for COMPONENT in "$SPARKLE_DEST/Versions/B/Autoupdate" \
                 "$SPARKLE_DEST/Versions/B/Updater.app" "$SPARKLE_DEST"; do
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$COMPONENT"
done

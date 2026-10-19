#!/bin/bash
# Builds a Styxpad release for other people: a universal app (Apple Silicon + Intel), signed with
# the Developer ID certificate, inside a DMG that Apple has notarized (checked for malware), so it
# opens on anyone's Mac without security warnings. The result goes in release/.
#
# One-time setup (stores your Apple ID credentials in the Keychain under the name below):
#   xcrun notarytool store-credentials "styxpad-notary" --apple-id YOUR_APPLE_ID --team-id 57NLMSPMRR

set -euo pipefail          # stop immediately if any step fails
cd "$(dirname "$0")"       # run from the project folder no matter where you call this from

IDENTITY="Developer ID Application"   # the certificate Apple requires for apps shared outside the App Store
NOTARY_PROFILE="styxpad-notary"       # the Keychain entry made by the setup command above
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
APP="release/Styxpad.app"
DMG="release/Styxpad-$VERSION.dmg"

# Check the notarization credentials first, so we don't build everything and then fail at the end.
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "Notarization credentials not found. Run the one-time setup command at the top of this script."
    exit 1
fi

echo "==> Building Styxpad $VERSION for Apple Silicon and Intel"
swift build -c release --arch arm64 --arch x86_64
BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Styxpad"

# Fail before replacing build output if this Mac lacks the matching update-signing key.
SPARKLE_TOOLS=".build/artifacts/sparkle/Sparkle/bin"
PUBLIC_KEY="$("$SPARKLE_TOOLS/generate_keys" --account Styxpad -p)"
EXPECTED_KEY=$(/usr/libexec/PlistBuddy -c "Print SUPublicEDKey" Resources/Info.plist)
test "$PUBLIC_KEY" = "$EXPECTED_KEY" || { echo "Sparkle signing key doesn't match Info.plist." >&2; exit 1; }

rm -rf release
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

echo "==> Signing the app"
bash Tools/embed-sparkle.sh "$APP" "$IDENTITY"
# --options runtime = the "hardened runtime" Apple requires for notarization.
# --timestamp = a secure timestamp from Apple, so the signature stays valid after the certificate expires.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# The styled "drag Styxpad into Applications" DMG (see make-dmg.sh).
./make-dmg.sh "$APP" "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing (uploading to Apple; usually takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"   # attach Apple's approval ticket, so it also works offline

echo "==> Checking that Gatekeeper accepts it"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

# Sign the final, stapled bytes. Publish this feed with the DMG on the same GitHub release.
echo "==> Generating the signed update feed"
if [ -f "docs/release-notes/$VERSION.html" ]; then
    cp "docs/release-notes/$VERSION.html" "release/Styxpad-$VERSION.html"
fi
"$SPARKLE_TOOLS/generate_appcast" --account Styxpad --maximum-deltas 0 \
    --download-url-prefix "https://github.com/EvenDog/Styxpad/releases/download/v$VERSION/" \
    --link "https://github.com/EvenDog/Styxpad/releases/tag/v$VERSION" \
    --embed-release-notes release

echo "Done: $DMG"
echo "Upload both $DMG and release/appcast.xml to the GitHub release."

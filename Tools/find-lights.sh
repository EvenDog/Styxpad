#!/bin/bash
# Builds and runs the light finder (Tools/LightFinder/main.swift): it lights the Tartarus Pro's
# backlight one light at a time and asks which key each one is under.
#
# Quit Styxpad first, then run from the project folder:  ./Tools/find-lights.sh

set -euo pipefail
cd "$(dirname "$0")/.."

WORK=$(mktemp -d)
# Built together with the app's own files, so it sends exactly the commands Styxpad sends.
swiftc -O -o "$WORK/light-finder" \
    Tools/LightFinder/main.swift \
    Sources/Styxpad/RazerProtocol.swift \
    Sources/Styxpad/Backlight.swift \
    Sources/Styxpad/TartarusLayout.swift \
    Sources/Styxpad/KeyCodes.swift
"$WORK/light-finder"
rm -rf "$WORK"

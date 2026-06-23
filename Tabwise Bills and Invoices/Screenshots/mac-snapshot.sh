#!/bin/bash
# macOS App Store screenshots for Invoice Tracker — fully headless.
# Builds the app and runs its built-in `--snapshot` mode (SwiftUI ImageRenderer),
# which renders each screen to a PNG with NO window and NO Screen Recording
# permission. Output: marketing-mac/*.png at 2560x1600 (a valid Mac App Store size).
# Run from the Screenshots/ dir:  bash mac-snapshot.sh
set -uo pipefail
cd "$(dirname "$0")"

PROJ="../InvoiceTracker.xcodeproj"
SCHEME="InvoiceTracker"
DD="/tmp/it-mac-snapshot"
APP="$DD/Build/Products/Debug/Invoice Tracker.app"
OUT="$(pwd)/marketing-mac"
mkdir -p "$OUT"

echo "== building macOS app =="
# ENABLE_DEBUG_DYLIB=NO avoids the separate preview/debug dylib whose codesign
# step is flaky in headless contexts; not needed for rendering.
xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination 'platform=macOS' \
  -configuration Debug -derivedDataPath "$DD" ENABLE_DEBUG_DYLIB=NO build 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -10
[ -d "$APP" ] || { echo "build failed (no app produced)"; exit 1; }

# The shipping build is sandboxed (entitlements), which blocks writing outside its
# container. Re-sign ad-hoc WITHOUT entitlements just for this local render so it
# can write the PNGs to a normal path. (Does not affect the archived/App Store build.)
codesign --force --deep --sign - "$APP" >/dev/null 2>&1

echo "== rendering screens =="
"$APP/Contents/MacOS/Invoice Tracker" --snapshot "$OUT"

echo "== results =="
for f in "$OUT"/*.png; do
  [ -e "$f" ] || { echo "(no pngs produced)"; exit 1; }
  echo "$(basename "$f") $(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk 'NR>1{print $2}' | paste -sd'x' -)"
done
echo "DONE"
